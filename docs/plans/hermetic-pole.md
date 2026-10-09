# Hermetic pole — make the push short

## RESUME HERE

**You were started with one sentence: `READ and FOLLOW docs/plans/hermetic-pole.md`. This section
is the ONLY CURRENT STATUS RECORD in this file.**

**THE GOAL, OPERATOR ORDER AT BATCH 217: EVERY PUSH IS SHORT. NOTHING ELSE IN AI-DLC OUTRANKS IT.** A push runs every
fixture it selects, so its wall clock tracks HOW MANY run, not the longest one. Measured at batch 217 on a gate's own log:
`read-set keys: 122 of 277 fixture(s) run (57 changed, 8 unrecorded, 57 stale)`. The pole premise this plan carried
through 0.760.0 was wrong. **No more pole sharding**: every new directory edits `setup-sites.md` and `core-manifest.md`
and re-runs about fifty fixtures on its own push.

**State: batch 217 built release work that is NOT on main.** main is whatever `origin/main` reads. Batch 216's 0.761.0
(`0e30bfeb`) is the last landed release this block knows of. ai-dlc-cc was gating a self-update fix as 0.762.0 when this
block was written, so take the next free number at push time.

The assembled batch-217 release is `release-0.762.0-durable` at `7502966d` on GitHub, squashed on `0e30bfeb`. Its gate
was STOPPED by the operator mid-suite, because its verdict store has a defect (below). It carries:

1. **A shared, per-project verdict store.** It lives at `${AI_DLC_VERDICT_STORE:-$HOME/.cache/ai-dlc/verdicts}/<root-commit>`,
   and is OFF in a shallow clone. `hermetic-run.sh` and the hook record a declared fixture's pass, and the hook skips a
   declared fixture whose entry matches. The key hashes the runner's `# HR_SANDBOX_BEGIN`/`END` span plus the hook's
   universe spans.
2. **Both pre-push hooks (I66).** A declared fixture with a stale record is decided on its declared keys. A passing
   unmapped fixture is traced on a red push. The `^"` guard reads only the `ls-files` streams, so one quoted map row no
   longer turns keying off. That last fix ends graph's every-push full run.
3. **42 more fixtures declared.** Isolation and teeth probes ran on all of them, and no gap was found.
4. **BL-481, first half.** The deriver drops `--level debug`; the `--local-map` liveness window is ~10s;
   `readset-sandbox-root-clause` retries up to ten windows.
5. **Four pole units sharded.**

**THE STORE DEFECT, measured on that gate.** The store skipped only 46 of about 104 declared fixtures it should have.
The cause is that the HOOK's key for a declared fixture is not the RUNNER's key. On `apply-drift-after-write` the hook
held 161 rows and `hermetic-run.sh --key-only` 67. The hook's extras were 88 tool rows, `.gitattributes` and 5
`#listing` rows. 52 of the 58 misses still carry rows in the committed `.ai-dlc-fixture-readsets.tsv`. Control: a store
hit, `adversarial-citation`, was byte-identical on both sides.

The root cause is DUPLICATION, not a bad line. These are written twice:
- the store path: `readset_vs_store` in the hook, `hr_store_put` in the runner;
- the digest input: `readset_vs_input`, and the runner around `:465`;
- a declared fixture's key rows: `readset_declared` + `readset_keys` in the hook, `hr_key_rows` in the runner.

The hook's comment above `readset_declared` claims `--key-only` "prints the same rows", and nothing enforces it.
The batch-217 lead's pre-gate "parity check" compared the runner to itself in two directories and never compared the
hook's lookup to the runner's write. That is why the defect reached a gate.

**IN FLIGHT AT HANDOFF.** `b217-vs-keyfix` at `f2237d9d`, on `7502966d`, holds NO code change. It holds only a
census script, `census-wip.sh.txt`, which compares the hook's computed `.k` rows with `hermetic-run.sh --key-only` for
every declared fixture.

Its one run used FRESH records, with no prior key record, and found 223 of 225 identical. The two that differ are
`layer-contract-conformance{,-b}`, where the hook has 1606 rows and the runner 1605; the extra row was not diffed.

So the traced-map-rows hypothesis is REFUTED for fresh records. The gate's 161-versus-67 gap needs a PRIOR record. The
suspect is the decision awk carrying an existing record's keys forward: `RK[f]` and the `ok`-record carry-over around
`.githooks/pre-push:1421` on `7502966d`.

Run the census with a seeded `stale` record and a seeded `ok` record first; that is where the gap should reproduce.
The single-sourcing of NEXT ACTIONS 2 is still required: two implementations are why the gap was invisible. On `main`,
the runner sources the hook's span at `core/scripts/hermetic-run.sh:244`, and the hook's declaration logic starts at
`.githooks/pre-push:1219`.

**Peers at handoff.**
- **ai-dlc-e2** holds `b218-git-decl` at `febd4027`, rebased on `7502966d`. It seeds a git repository inside the sandbox
  (`git.decl`: `seed`, `pin <sha>`, `pin? <sha>`) for `prepush-pool-depth`, both `procsub` parents and
  `retired-layer-contract`. Its rule: a pass that skipped an optional pin is never recorded, `hr_pin_skipped` in
  `hr_store_put`. It gates after the store fix lands, taking the next free number at push time.
- **ai-dlc-a3** holds `b218-inpool-trace`, WIP. It traces an undeclared fixture during the suite's own run, in a
  `clonefile` list-clone, so its rows come from the run that produced the verdict and the detached second run
  disappears. The loss canary stays. It builds on e2's tip.
- **ai-dlc-cc** shipped 0.761.0 and was gating its self-update fix as 0.762.0.

Ask each for its current state; do not trust this paragraph.

Your instructions are four sections: `## Start here`, `### NEXT ACTIONS`, `### Ping the operator`,
`### Done when`.

## Start here

**Three trees, and only one of them is yours to write.** `<scratch>/ai-dlc-pole`, a full clone under
`mktemp -d` with a `github` remote, pinned at `github/main`: WRITE, every edit and commit of this plan
happens there. `/Users/n8/git/ai-dlc`, the operator's main checkout: read `.git/ai-dlc-fixture-*` with
`cat` only, and use it for the gated push only, detached at the release commit, after asking every
live `ai-dlc-*` session for its window; every linked worktree under its `.claude/worktrees/` is bound
by the same rule. `/Users/n8/git/graph`, the consumer: read it, never write it, and NEVER message a `graph-*` session
without an explicit operator grant, not even a read-only question. Learn about consumer activity from the process table
and block on its pid.

**Every hand brief carries these lines.** `isolation: "remote"`; a `mktemp -d` under the scratchpad; no `rm -rf` on a
variable path; no load generator; `--no-verify` on every push the hand makes; no work under
`/Users/n8/git/ai-dlc/.claude/worktrees/`. **Never `pkill`, `killall` or kill by pattern**: stop only processes you
started, by the pid or process group recorded when you started them. A batch-217 hand's `pkill -f hermetic-run.sh` was
in the window when graph's push was SIGTERMed. **Every run that invokes `hermetic-run.sh` sets `AI_DLC_VERDICT_STORE` to
a mktemp dir**: a test run without it wrote 184 entries into the real store. Remove every worktree a hand leaves before
reporting closed. A wait loop has an exit: a pid or a capped count, never only a marker that may never come.

**Measure only what a decision reads.** Operator ruling at batch 217: no solo timings, because no gate or done-when reads
them. The figures this plan is judged on are an ordinary push's `read-set keys:` run count and its `verdict store: N
fixture(s) skipped` line, with the fixture-suite wall clock and load beside them.

### Derive the state; do not trust the numbers above

```bash
git rev-parse --short HEAD; git status --porcelain | wc -l
git ls-remote github refs/heads/main refs/heads/release-0.762.0-durable refs/heads/b217-vs-keyfix refs/heads/b218-git-decl refs/heads/b218-inpool-trace
n=0; for d in core/fixtures/*/; do [ -f "$d/inputs.decl" ] && n=$((n+1)); done; echo "DECLARED $n"   # 225 on 7502966d
# store duplication: these must print 0 once single-sourced (the runner's own copies are gone)
git show github/b217-vs-keyfix:core/scripts/hermetic-run.sh 2>/dev/null | grep -c '^hr_key_rows()\|^hr_store_put()'
# the real verdict store, READ ONLY; control: the base directory exists
ls ~/.cache/ai-dlc/verdicts/ 2>/dev/null | head; ls -d ~/.cache/ai-dlc/verdicts 2>/dev/null | wc -l
uptime
```

### NEXT ACTIONS — numbered, in order

1. **MAKE THE CLONE AND PIN IT** at `github/main`; ask every live `ai-dlc-*` session (`ListAgents`) what
   release number and batch number it holds and whether it holds the main checkout; WAIT for every answer;
   state the number you take to every one of them before building.
2. **SINGLE-SOURCE THE STORE**, on `b217-vs-keyfix` (or from `7502966d`), in BOTH hooks identically (I66).
   - ONE function each for the store path, the digest input, and a declared fixture's key rows, in a span both the hook
     and `hermetic-run.sh` source. The runner already sources the hook's `READSET_UNIVERSE` span; extend it or add one.
   - DELETE the runner's own copies.
   - Make the RUNNER the store's only writer: delete `readset_vs_put` and its call in `readset_keys_write` from both
     hooks. Every declared fixture the hook runs goes through the runner at the `if [ -f "$d/inputs.decl" ]; then`
     dispatch, so confirm that in both layouts first. e2's `hr_pin_skipped` rule then covers every write.
   - Traced map rows must never enter a declared fixture's key.
   - If the hook's key composition cannot be lifted into a sourced span, report why before building anything else.
   - Keep these five texts byte-for-byte, because ai-dlc-cc's self-update fix matches on them: `# READSET_TOOLS_BEGIN`,
     the dispatch line, `declared file absent:`, and the `rc=`/`sandbox_files=`/`required_missing=` summary line.
3. **THE CENSUS IS A GATE ARM, NOT A CLAIM.** Add a fixture arm that runs on the REAL tree and, for every declared
   fixture, byte-compares the hook's computed key rows with `hermetic-run.sh --key-only`. It must name the fixture and
   the first differing row on any mismatch. Key it on both hooks, `hermetic-run.sh` and the shared span, so it re-runs
   at every gate that touches key code. Add a mutant that edits one side only, which must fail it. Report the census
   line and its count from a real run. **No one asserts the key is final; this arm passing at the gate is the only
   evidence.**
4. **RE-SQUASH, RE-SEED, GATE.**
   - Squash onto the then-current `origin/main` as the next free version. Rewrite the 0.762.0 CHANGELOG entry of
     `7502966d` under the new number, and add the single-sourcing.
   - DELETE every entry under `~/.cache/ai-dlc/verdicts/`: every existing entry was recorded under the defective key.
     Delete by exact listing, never a glob on a variable.
   - Seed: run every declared fixture once through the release tree's `hermetic-run.sh` from a clean clone at the
     release commit. Check the clone's `--key-only` rows against the main checkout's for a few fixtures first.
   - GATE START to every `ai-dlc-*` session. Gate from the main checkout detached at the release commit, creating
     `release/<version>`, `AI_DLC_FIXTURE_JOBS=12`.
   - Read: the exit file; the census arm by name; `verdict store: N skipped`, which must be near the count of declared
     fixtures the push would otherwise run; the `read-set keys:` line; `ls-remote` for the ref.
   - `readset-sandbox-root-clause` fails above about load 60, the open half of BL-481. Run it alone first if load is
     high.
5. **MEASURE AN ORDINARY PUSH.** After the release lands, the next docs-only or single-fixture push's `read-set keys:` run
   count and `verdict store:` line are the figures this plan is judged on. Record them with load beside them.
6. **CARRIERS OWED** in the docs commit after the release:
   - in `.claude/rules/tool-hazards.md`: "never kill by pattern; stop only your own recorded pid", and "a test that runs
     `hermetic-run.sh` sets `AI_DLC_VERDICT_STORE`";
   - in `.claude/rules/operator-rulings.md`: "never message a `graph-*` session without an explicit grant";
   - in `verification-discipline.md`: one sentence saying a fixture named on the `verdict store:` line was skipped on a
     recorded pass, which is not a read-set gap.
7. **RE-DERIVE THIS BLOCK**, `bash scripts/validate-plan-shape.sh`, commit, push once from the clone.
8. **FRESH-RESUME CHECK**: merge the docs commit, fresh clone of `origin/main` through the `github`
   remote's URL, read this plan there, re-run the derive block, assert the numbered actions name
   nothing already shipped, run the plan validator there as the floor.
9. **HAND THE PLAN TO A LOCAL AI-DLC SESSION, THEN STOP.** `ListAgents`; if a local `ai-dlc-*`
   session is found (never a `graph-*` one), `SendMessage` it exactly
   `READ and FOLLOW docs/plans/hermetic-pole.md` and nothing else. A `REFUSED:` reply advances to the
   next untried session, idle ones first; silence does not. Once a session accepts, this session has
   no further work and communicates no further with it. If none is found, there is nothing further to
   do.

### Ping the operator

Report on every question, every decision, and on completion including an early stop. Specifically:
when the single-sourcing cannot lift the hook's key composition into a sourced span; when the census
reports a mismatch; when the store's skip count at a gate is far below the declared fixtures the push would
otherwise run; and when the release lands, with the ordinary push's run count and wall clock. Present a stall
as choices with a marked recommendation. Never narrow the scope on your own authority.

### Done when

1. The pole work of 0.757.0 and 0.760.0 is MET and closed; the pole is no longer this plan's measure.
2. The verdict store's key is single-sourced: the census arm reports every declared fixture's hook key equal to its
   runner key, on the real tree, at the gate that ships it, and its one-side mutant is killed.
3. That release has landed, and its gate printed a `verdict store: N skipped` line covering the declared fixtures the
   push would otherwise have run.
4. An ordinary push after it (no hook, runner or deriver change) shows its `read-set keys:` run count and fixture-suite
   wall clock, with load beside them, recorded here against the batch-217 baseline of 122 run.
5. The six carriers of action 6 are committed, this block re-derived, the plan validator green, the fresh-resume check
   passed, the plan handed on.
