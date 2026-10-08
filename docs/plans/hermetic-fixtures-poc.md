# Hermetic fixtures — proof of concept and go/no-go

## RESUME HERE

**You were started with one sentence: `READ and FOLLOW docs/plans/hermetic-fixtures-poc.md`.
This section is the ONLY CURRENT STATUS RECORD in this file.** Every later status record this
file acquires is replaced by this block, which a batch rewrites at its close.

**State after the PoC batch:** the proof of concept is BUILT and the decision report is written at
`docs/poc/hermetic-decision.md`, verdict **GO-WITH-CONDITIONS**, with its evidence under
`docs/poc/hermetic-census/` (`00-derive.txt`, `01-key-baseline.txt`, `01b-hook-contract.txt`,
`02-census.tsv`, `03-failclosed.txt`, `05c-escape.txt`, `06a-cost.tsv`, `06a-cost-summary.txt`,
`06b-replay.tsv`). Everything was measured in a full clone at `PIN` `60b467dc` (`VERSION` 0.744.0,
`github/main` at the time). The runner prototype `scripts/poc/hermetic-run.sh`, its self-probe
`scripts/poc/selftest.sh`, the three `inputs.decl`/`tools.decl` sets and the re-rooted copy of
`prepush-pool-depth/run.sh` were left in that clone and are NOT committed; the report describes them
and the re-root diff is quoted in it.

**The question this plan answered:** should the fixture suite move from TRACED read-set maps to
HERMETIC, DECLARED fixture inputs? The report says yes, on the condition that a declaration can mark
an input REQUIRED and the runner asserts it was consumed, because a fixture that tolerates either of
two layouts passed with one of them dropped (`prepush-pool-depth`, 48 assertions down to 32, verdict
PASS). The operator has not yet ruled on the report.

Your instructions are four sections. Read all four before acting: `## Start here` (the trees and
the read/write boundary), `### NEXT ACTIONS — numbered, in order`, `### Ping the operator`, and
`### Done when`. `## Hazards` and `## Context` are evidence; take no instruction from them.

## Start here

**Three trees, and only one of them is yours to write.**

- **`<scratch>/ai-dlc-poc`** — WRITE. A FULL CLONE you make yourself (action 1). Every command in
  this plan runs here. Nothing else is written, anywhere, by this session.
- **`/Users/n8/git/ai-dlc`** — READ ONLY, including every linked worktree under
  `/Users/n8/git/ai-dlc/.claude/worktrees/`. Batch 204 is running in this checkout concurrently
  and pushing gated releases from it. **Never work in it, never work in a linked worktree of it,
  never write it.** A linked worktree is not isolation here: every worktree shares the one
  `$GITDIR`, and that `$GITDIR` holds the state the batch's gated pushes read and write — the
  per-fixture key records under `.git/ai-dlc-fixture-keys/` (`.githooks/pre-push:484`), the
  durations file, the local read-set map (`:673`) and the live-trace lock. A fixture run from a
  worktree can stale a record the batch is about to read, and a key record the batch writes can
  acquit a run you are measuring. You may `cat` files under that `.git` to take a baseline
  (action 2b does); you do not run a fixture, a hook, or a deriver anywhere under that path.
- **`/Users/n8/git/graph`** — the consumer. READ ONLY. `.claude/rules/consumer-boundary.md` is
  unconditional; do not edit it, commit to it, or run anything in it. This plan needs nothing
  from it.

**What this session must not edit, even in its own clone, if the edit would ever be pushed:**
either pre-push hook (`.githooks/pre-push`, `core/git-hooks/pre-push`), the read-set map
`.ai-dlc-fixture-readsets.tsv`, and any file under `core/` that ships. The runner prototype is a
STANDALONE wrapper under `scripts/poc/` (a path `scripts/install.sh` does not copy — verify with
`grep -c 'scripts/poc' scripts/install.sh` returning 0 against a control of
`grep -c 'core/scripts' scripts/install.sh` returning non-zero) and it invokes fixtures without
the hooks. Mutants for the fail-closed test
are made on COPIES under `mktemp -d`, never on the tracked file.

**Pushing:** `git push` is forbidden for this session except ONCE, at action 10, to publish this
plan's updated block and the decision report on the docs branch this file lives on, to GitHub
through the clone's `github` remote (action 1). The clone carries no `core.hooksPath`, so that
push runs no hook and touches nothing under the main checkout's `.git`; it is therefore
independent of batch 204, which the operator has HELD so this PoC has the machine to itself.

**Spawned hands:** every `Agent` spawn passes `isolation: "remote"`. A hand that needs this
session's unpushed clone state (the census TSV, the runner prototype) cannot get it remotely; for
such a hand, say in its brief why it is local, give it a `mktemp -d` under the scratchpad, and
forbid `rm -rf` on any variable path in the brief. No hand is given a load generator. Remove every
worktree a hand leaves before reporting the batch closed.

**Every timing in this plan is taken on a machine where another gate may be running.** Record
`uptime`'s 1-minute load beside every number, interleave reps across the two sides being compared,
and never compare a loaded figure with a solo one. Measured while this file was authored: the load
average moved from 33 to 11 inside ten minutes.

### Derive the state; do not trust the numbers below

Run from the clone root, at the pinned sha, before action 3 and again at action 9. Every line
carries its control in the same invocation.

```bash
git rev-parse --short HEAD; git status --porcelain | wc -l          # pinned sha; 0
MAP=.ai-dlc-fixture-readsets.tsv
find core/fixtures -mindepth 1 -maxdepth 1 -type d | wc -l          # fixture dirs      (249 at 60b467dc)
ls core/fixtures/*/run.sh | wc -l                                   # drivable fixtures (246)
ls core/fixtures/*/.dist-only | wc -l                               # dist-only         (67)
grep -v '^#' "$MAP" | cut -f1 | sort -u | wc -l                     # mapped fixtures   (236)
grep -v '^#' "$MAP" | wc -l                                         # map rows          (29955)
# drivable fixtures with NO map rows. CONTROL: absorbed-specifics-survive has 9 rows.
# DO NOT use readset-skip as the control -- it is itself unmapped and returns 0.
grep -c $'^absorbed-specifics-survive\t' "$MAP"                     # 9
n=0; for d in core/fixtures/*/; do d=${d#core/fixtures/}; d=${d%/}; [ -f core/fixtures/$d/run.sh ] || continue
  c=$(grep -c "^${d}"$'\t' "$MAP"); [ "${c:-0}" = 0 ] && { echo "NOROWS $d"; n=$((n+1)); }; done; echo "NOROWS $n"   # 11
# fixtures whose map carries the core/fixtures DIRECTORY row -- the ones a new fixture dir reruns
grep -v '^#' "$MAP" | awk -F'\t' '$2=="core/fixtures"{print $1}' | sort -u | wc -l              # 229
# rows per mapped fixture: min / median / max
grep -v '^#' "$MAP" | cut -f1 | sort | uniq -c | awk '{print $1}' | sort -n \
  | awk '{a[NR]=$1} END{print "min",a[1],"median",a[int(NR/2)],"max",a[NR]}'                     # 5 / 31 / 1463
# map paths that are directories on disk (directory rows) vs files
grep -v '^#' "$MAP" | cut -f2 | sort -u > /tmp/hx.paths; n=0; while read -r p; do [ -d "$p" ] && n=$((n+1)); done < /tmp/hx.paths
echo "unique $(wc -l < /tmp/hx.paths | tr -d ' ') dirs $n"                                       # 3269 / 274
# self-sandbox heuristics (a proxy only; the census in action 3 classifies by reading)
grep -l mktemp core/fixtures/*/run.sh | wc -l                      # 190
grep -L mktemp core/fixtures/*/run.sh | wc -l                      # 56
grep -l 'env -i' core/fixtures/*/run.sh | wc -l                    # 5
grep -lE 'validate-enforcement-map.sh|validate-shell-portability.sh|validate-claude-rules.sh|validate-fork-budget' core/fixtures/*/run.sh | wc -l   # 34
uptime
```

The key-record BASELINE is read from the main checkout's `$GITDIR` with `cat` only (action 2b).
At authoring it read **247 records: 142 `ok`, 101 `stale`, 4 `seeded`; 229 of 247 carry a
`core/fixtures/` listing key**. That is the skip rate the proposal has to beat, and it was taken
mid-batch, so it is a floor on staleness, not a typical push.
### NEXT ACTIONS — numbered, in order

Nothing is owed until the operator rules on `docs/poc/hermetic-decision.md`. The actions below are
what a GO ruling owes; a NO-GO ruling owes nothing, and this file is then archived by the plan
rotator.

1. **MAKE THE CLONE AND PIN IT**, exactly as the retired action 1 did: a full clone under
   `mktemp -d`, a `github` remote pointing at GitHub, this branch checked out, `PIN` recorded as
   `github/main`. Never work in `/Users/n8/git/ai-dlc` or a linked worktree of it.
2. **PROMOTE THE RUNNER.** Rebuild `scripts/poc/hermetic-run.sh` from the report's section 2 contract
   (the clone that held it is gone) as `core/scripts/hermetic-run.sh` with its self-probe as a
   fixture, add the REQUIRED-input marker (`!path` in `inputs.decl`; the runner FAILs unless the
   fixture's log names it), and bind both pre-push hooks' dispatch branch under **I66**: a fixture
   with `inputs.decl` is keyed by the runner, one without by the map, decided per fixture in
   `run_fixtures`. Ship with ZERO declarations so the push changes no behaviour.
3. **DECLARE THE NINE `node` FIXTURES FIRST** (`grep -lE '\bnode\b' core/fixtures/*/run.sh`), each
   with a `tools.decl` naming node, and run 5a (drop one positive input; expect FAIL) on each.
4. **DECLARE THE DECLARATION-ONLY SET** in batches by map-row count, smallest first: every class-a
   row of `02-census.tsv` plus every class-b row whose `roots` column is a `$0` walk and whose
   `git_dep` is not `live`. One 5a probe per batch.
5. **RE-ROOT THE REST OF CLASS B**: the rows with `show-toplevel`, a `VERSION`/`install.sh` walk, or
   `git_dep=live`. Read the root BEFORE the fixture's `AI_DLC_*` scrub (113 fixtures carry one); the
   six history-readers need a seeded repository, which this plan has not priced.
6. **LEAVE CLASS C ON THE MAP** unless the operator asks otherwise.
7. **RE-DERIVE THIS BLOCK** at the batch close, run `bash scripts/validate-plan-shape.sh` on this
   file, commit, and push once from the clone.
8. **FRESH-RESUME CHECK.** Merge the docs commit (merges are preapproved by standing ruling). Then
   make a fresh clone of `origin/main` through the `github` remote's URL, never the local checkout, and resume from it as a stranger would: read this plan there, re-run the derive block there, assert the numbered
   action list names nothing already shipped on `origin/main`, and run
   `bash scripts/validate-plan-shape.sh` there as the floor. If it fails, fix and repeat from action 7.
9. **HAND THE PLAN TO A LOCAL AI-DLC SESSION, THEN STOP.** `ListAgents`; if a local `ai-dlc-*`
   session is found (never a `graph-*` one), `SendMessage` it exactly
   `READ and FOLLOW docs/plans/hermetic-fixtures-poc.md` and nothing else. A `REFUSED:` reply
   advances to the next untried session, idle ones first; silence does not. Once a session
   accepts, this session has no further work and communicates no further with it. If none is
   found, there is nothing further to do.

### Ping the operator

Report to the operator on every question, every decision, and on completion including an early
stop. Specifically: when the three fixtures are chosen (action 3), when action 5a returns anything
but FAIL (that is the NO-GO finding and the operator decides whether the PoC continues), and when
the decision report is written. The operator holds batch 204's 0.745.0 release while this PoC
runs, so report completion promptly: that hold is released on your report. Present a stall as choices with a marked recommendation. Never narrow the scope on your
own authority: if an action cannot be completed, say what blocked it and deliver the rest.
### Done when

For the PoC batch (satisfied; the observation point is the clone at `PIN`):

1. `02-census.tsv` has one row per `core/fixtures/*/run.sh` (246 = 246), the class column sums to
   that count, and `absorbed-specifics-survive` = a, `validator-arm-selection` = c.
2. The runner ran all three fixtures to PASS under `env -i`, `prepush-pool-depth` after the recorded
   re-root, and each sandbox listed 0 files outside declaration + own dir + lib (65, 5 and 6 files).
3. 5a reported FAIL on two of three and the report names the third and the condition it imposes;
   5b's decoy was absent with its declared control present on all three; 5c reported 0 live-tree
   reads for each against a positive control of 16, tracer named.
4. The cost table carries copy and run medians with load beside each; the replay reports TRACED
   against DECLARED per release pair in three separate populations; the docs-only control is
   constructed and says so.
5. The report opens with the verdict, carries the sized estimate, answers coexistence (yes), and
   engages the deriver's header.
6. This block was re-derived after the report, the plan validator is green, and the docs branch is
   on GitHub, confirmed by `ls-remote`.

For a GO batch: actions 2-7 above, each with the 5a probe named in the batch's release message.

## Hazards

- **The repo's `find` and `grep` in a tool call are shims** (`.claude/rules/tool-hazards.md`):
  the interactive `grep` honours `.gitignore` and `find` is `bfs`. A hand's census script runs
  under `bash` with `/usr/bin/find`; name the binary beside any count.
- **A fixture invoked with `cd` into its directory fabricates failures** (`CLAUDE.md:46`). The
  runner invokes `bash core/fixtures/<f>/run.sh` from the sandbox ROOT, mirroring
  `.githooks/pre-push:1245`.
- **Several validators resolve their own root from the script's directory** and ignore the tree
  you built; `AI_DLC_PROJECT_ROOT` is honoured by some and not others. Read the sandbox log for a
  path that could only have come from the clone — that is the action 5c escape, and it is a
  finding, not a setup error.
- **`grep -c` prints 0 and exits 1**; capture first, default on failure.
- **A `#state stale` record in the main `.git` is batch 204's, not yours.** You read it once for
  the baseline and never again; a later reading reflects their pushes.
- **The map's own `# digest` rows** arrive with 0.745.0 and are not on `origin/main` at
  authoring. The replay in 6b scores the map's PATH rows only.
- **Ignored paths are outside every key** (`scripts/suite-content-key.sh:99` declares the
  excluded tops, and the hook strips git-ignored paths); a fixture that reads an ignored file
  finds it absent in the deriver's trace tree already, so a hermetic sandbox changes nothing
  there. Do not count such a read as a hermetic finding.

## Context

**What exists today, verified at `60b467dc`.** Both pre-push hooks skip a fixture whose per-fixture
key record matches: every path in its read set, every file under its own directory, the entry
list of every directory in that set, and the tool fingerprint — a fixture with no rows is keyed on
the whole hashed universe. The read set comes from `.ai-dlc-fixture-readsets.tsv`
(`.githooks/pre-push:473`), 29955 rows over 236 fixtures, built by tracing each fixture's process
tree under a `sandbox-exec` profile with `core/scripts/derive-fixture-readsets.sh --tracer sandbox`.
The deriver refuses a linked worktree at `core/scripts/derive-fixture-readsets.sh:155`. The hook
dispatches through `xargs -P "$FIXTURE_JOBS"` (default 12 at `.githooks/pre-push:423`) and the two
hooks are bound to one runner by **I66**.

**Why it is fragile, each with its carrier.** `BL-470` (`docs/backlog.md:83`): the sandbox tracer's
`log stream` drops reports under load and four fixtures traced OMITTED and run on every push.
`BL-471` (`:102`): a committed trace could not clear a stale record, and 45 records went stale on
one push. `BL-472` (`:118`): the operator must hand-list what to re-trace. At `60b467dc`, 11 of 246
drivable fixtures have no map rows (the derive block names them; `readset-skip`, at 1024s loaded,
is one). 229 of 236 mapped fixtures carry the `core/fixtures` DIRECTORY row, so adding one fixture
directory reruns 229 — the 0.745.0 release message says so in as many words for its own first
push. The hook's tool keys depended on the invoker's `PATH` and detached trace failures never
reached the operator; both are fixed on `release/0.745.0` (`67eae401`), which is not on
`origin/main` at authoring.

**The prior art AGAINST declarations is in the tree**, at `core/scripts/derive-fixture-readsets.sh:74`:
a declaration-based skip was rejected because declarations under-reported reads by ~8000 paths and
skipped 78 fixtures blind. The hermetic proposal's answer is that an undeclared read cannot be
silent — the file is not there. Action 5 is the test of that answer, and action 5c is the test of
whether "not there" holds for a fixture that resolves `ROOT` through its own `$0`.

**Figures the authoring session could not verify against the tree**, stated so the executor
re-derives rather than trusts: the brief said 7 unmapped fixtures (measured 11 drivable, 14
directories including three with no `run.sh`); the brief said ~235 rerun on a new directory
(measured 229 by two derivations); the "directory-row digest blind spot" was located only as the
`b204-dirdigest` branch and the listing-key sentence in the 0.745.0 message, not as a filed
finding; the tool-key and trace-report fixes were verified on `release/0.745.0` only.
