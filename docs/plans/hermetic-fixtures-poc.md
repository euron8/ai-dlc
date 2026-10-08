# Hermetic fixtures — proof of concept and go/no-go

## RESUME HERE

**You were started with one sentence: `READ and FOLLOW docs/plans/hermetic-fixtures-poc.md`.
This section is the ONLY CURRENT STATUS RECORD in this file.** Every later status record this
file acquires is replaced by this block, which a batch rewrites at its close (action 9).

**State at authoring:** nothing has been built. The census below was taken ONCE, by the authoring
session, at `origin/main` `60b467dc` (`VERSION` 0.744.0), read-only, to size the PoC and to pick
its three fixtures. Every figure in this file is a hypothesis about a tree that has moved; the
derive block in `### Derive the state` re-takes all of them in under a minute.

**The question this plan answers:** should the fixture suite move from TRACED read-set maps to
HERMETIC, DECLARED fixture inputs? The deliverable is a go/no-go DECISION REPORT to the operator
with evidence, a census, a sized estimate of the full refactor, and a migration path. The
deliverable is NOT the refactor.

Your instructions are four sections. Read all four before acting: `## Start here` (the trees and
the read/write boundary — read this FIRST), `### NEXT ACTIONS — numbered, in order`, `### Ping the
operator`, and `### Done when`. `## Hazards` and `## Context` are evidence; take no instruction
from them.

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
plan's updated block and the decision report on the docs branch this file lives on, and only after
the gate in action 10 says no batch-204 push is in flight. `ps` is not a liveness probe
(`.claude/rules/tool-hazards.md`, Environment floor); the gate is `git ls-remote` against origin
plus asking the operator.

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

1. **MAKE THE CLONE AND PIN IT.** `S="$(mktemp -d "${TMPDIR:-/tmp}/ai-dlc-poc.XXXXXX")"`,
   `git clone -q /Users/n8/git/ai-dlc "$S/ai-dlc-poc"`, `cd "$S/ai-dlc-poc"`,
   `git fetch -q origin`, then `git checkout -q -b poc/hermetic-fixtures origin/main`. A clone of
   the main checkout gives you its LOCAL `main`, which is batch 204's moving tip — the branch you
   just cut from `origin/main` is the pin. Record `git rev-parse HEAD` as `PIN` and take every
   figure in this plan at `PIN`. Confirm `git rev-parse --git-dir` prints `.git` (a directory in
   your clone, not a file pointing at the main checkout), and confirm
   `git worktree list | wc -l` prints 1. Record `git config --get core.hooksPath` (expected:
   empty — a fresh clone carries no hooks path, so the push in action 10 runs NEITHER pre-push
   hook and action 9's validator run is the only floor; do not set it, or the push will run the
   full suite in the clone on a loaded box). Set `AI_DLC_PROJECT_ROOT="$S/ai-dlc-poc"` in every shell
   that drives a validator, because several resolve their own root from the script's directory
   and would otherwise answer about whichever tree they were copied from.

2. **TAKE THE BASELINES, READ-ONLY.**
   - 2a. Run the derive block above in the clone. Write its output to `docs/poc/hermetic-census/00-derive.txt`
     with `uptime` on the last line.
   - 2b. Read the main checkout's key records with `cat` and `grep` only:
     `grep -h '^#state' /Users/n8/git/ai-dlc/.git/ai-dlc-fixture-keys/*.key | sort | uniq -c`,
     the count of records carrying `^core/fixtures/<TAB>#listing`, and the top four lines of
     `/Users/n8/git/ai-dlc/.git/ai-dlc-fixture-durations` sorted by cost. Write them to
     `docs/poc/hermetic-census/01-key-baseline.txt` with the time and the batch-204 `origin/main`
     sha beside them. These are loaded, mid-batch numbers and the file says so.
   - 2c. Record the hook's current contract by FUNCTION NAME, not line: `readset_tools`,
     `run_fixtures`, `KEYS_DIR`, `READSET_LOCAL`, `READSET_MAP` (`grep -n` each in
     `.githooks/pre-push` at `PIN`). 0.745.0 rewrites both hooks and is not on `origin/main` at
     authoring; every hook line number in this file was taken at `60b467dc` and will move.

3. **THE CENSUS (read-only; one hand per class, `isolation: "remote"`, each writes a TSV and
   returns its counts AS TEXT).** Classify every drivable fixture (every `core/fixtures/*/run.sh`)
   into exactly one of:
   - **(a) already self-sandboxed** — builds its subject under `mktemp -d`, sources
     `core/fixtures/lib/preamble.sh:31` or unsets `GIT_DIR` itself, and reads the live tree only
     to COPY named inputs into the sandbox.
   - **(b) reads the live repo root** — resolves `ROOT` by walking up from `$0` (the
     `ROOT="$(cd "$HERE/../../.." && pwd)"` shape appears in 49 `run.sh` files at `PIN`) and then
     reads or invokes files under it in place, or reads `.git/` of the live repo.
   - **(c) whole-tree validator** — its verdict is a property of the whole tree: it invokes
     `scripts/validate-enforcement-map.sh`, `validate-shell-portability.sh`,
     `validate-claude-rules.sh`, `validate-fork-budget.sh`, or walks `core/**` or `scripts/**`
     with `find` or `git ls-files`. 34 fixtures name one of those validators at `PIN`; that is the
     grep floor, not the class.
   The method: read each `run.sh` (the mktemp grep is a proxy that mis-classifies — a mutant
   battery with no `mktemp` can still be (a) through a helper), record the `.git` dependence as
   its own column (`none` / `own scratch repo` / `live .git`), and record the row count from the
   committed map as the declaration-size proxy (file rows only; drop the 274 directory paths).
   Control: the three classes plus an `unclassifiable` column must sum to the `run.sh` count, and
   `absorbed-specifics-survive` (mktemp at `core/fixtures/absorbed-specifics-survive/run.sh:42`)
   must land in (a) while `validator-arm-selection` (drives the enforcement-map validator from
   `core/fixtures/validator-arm-selection/run.sh:155`) lands in (c). Output:
   `docs/poc/hermetic-census/02-census.tsv` with columns
   `fixture  class  git_dep  map_file_rows  skip_arm  notes`, where `skip_arm` is `yes` when the
   fixture emits a `SKIP` verdict on a missing subject (`validator-arm-selection/run.sh:151` is
   the reference shape). Pick the three PoC fixtures from it: one (a) with a non-trivial copy set,
   one (b) whose git dependence is `live .git` (so the `.git` question is answered by the PoC and
   not deferred), and one with the deepest sourcing chain (most `core/scripts/*.sh` invoked
   transitively; the top map-row fixtures — `validator-arm-selection` 1463, `validator-fork-budget`
   1455, `layer-contract-conformance` 1418 at `PIN` — are candidates, but prefer one that is NOT
   class (c) so the depth and the whole-tree question stay separable). At least one of the three
   must carry a `SKIP` arm. State the three and the reason for each in the report.

4. **THE RUNNER PROTOTYPE, standalone, no hook edits.** `scripts/poc/hermetic-run.sh <fixture>`:
   - reads `core/fixtures/<fixture>/inputs.decl` (one project-relative path per line; a trailing
     `/` means the directory's files recursively; `.git` is NOT declarable in the first cut — a
     fixture needing a repository builds one in its sandbox, which the preamble already
     supports), and `tools.decl` (absolute tool paths);
   - builds `mktemp -d`, copies ONLY the declared inputs plus the fixture's own directory plus
     `core/fixtures/lib/`, preserving modes with `tar` the way `readset_copy_tree` does at
     `core/scripts/derive-fixture-readsets.sh:419` (not `cp -R`, for the symlink reason in its
     header);
   - runs `env -i PATH=<fixed list from readset_tools at PIN> HOME=<sandbox>/home
     GIT_CONFIG_NOSYSTEM=1 AI_DLC_PROJECT_ROOT=<sandbox> bash core/fixtures/<fixture>/run.sh`
     inside the sandbox, with `GIT_DIR` and friends unset;
   - prints the cache key: `sha256` over the sorted `(path, content-sha)` list of the copied set
     plus the `(tool, content-sha)` list plus the pinned env string;
   - **treats ANY verdict that is not the fixture's own PASS line as FAIL — including `SKIP`, an
     empty log, and a missing verdict.** A fixture that cannot find its subject SKIPs
     (`validator-arm-selection/run.sh:151`), and SKIP is the "pass or skip" outcome the
     fail-closed test exists to forbid.
   Write the three `inputs.decl` files by hand from the census row and the fixture's source,
   not from the map (the map is what is being replaced; a declaration derived from it inherits
   its gaps). Run each of the three under the runner with `uptime` beside each wall clock. The
   (a) fixture and the deep-sourcing fixture PASS. **The (b) fixture is expected to FAIL on its
   first run** — it reads a live `.git` the sandbox does not hold — and that FAIL is recorded as
   the baseline for action 5c. Then re-root a COPY of its `run.sh` (under `mktemp -d`, the
   tracked file untouched) so it builds its repository inside the sandbox through
   `core/fixtures/lib/preamble.sh:31` and resolves `ROOT` from `AI_DLC_PROJECT_ROOT`, run it
   again to PASS, and keep the `diff` of that re-root: it is the per-fixture effort figure
   action 7 prices for class (b).

5. **THE FAIL-CLOSED TEST — the decisive one.** For each of the three fixtures, on a COPY of its
   declaration under `mktemp -d`:
   - 5a. Remove ONE input the verdict positively depends on (not a negative-control file — a
     dropped negative control passes by construction). The runner must report FAIL, naming the
     fixture, with the fixture's log showing the missing path. PASS or SKIP here is a NO-GO
     finding for the runner, and the report says so in those words.
   - 5b. The decoy mutant: plant a file in the LIVE clone at a path the fixture would read if it
     could (choose one its source names and the declaration omits; for a (b) fixture, a path
     under the live `ROOT`), run under the runner, and assert the sandbox does not contain it
     (`[ ! -e "$SANDBOX/<decoy>" ]`) AND that the fixture's log never names it. Control in the
     same invocation: the same decoy ADDED to the declaration IS present in the sandbox.
   - 5c. The sandbox-escape probe: with the decoy present and undeclared, trace the run with the
     deriver's sandbox profile machinery if it can be driven standalone, or with
     `fs_usage` if the operator grants root — and state which. A read of the decoy's live path
     from inside the sandbox is an escape: the fixture resolved `ROOT` through `$0` to the
     CLONE, not the sandbox. Report the count of live-tree reads for each of the three; a
     non-zero count for the (b) fixture is the expected finding, and the report sizes what it
     would take to make that fixture resolve inside the sandbox.
   Each arm reports both directions; a probe that only fires is not a probe.

6. **COST.**
   - 6a. Copy overhead: time the runner's copy phase alone for each of the three (five reps,
     interleaved a-b-c-a-b-c, load beside each), and the fixture's own run time under the runner
     against its run time invoked directly from the clone root (the way `.githooks/pre-push:1245`
     invokes it), same interleaving. Report `median copy / median run` per fixture.
   - 6b. Skip-rate replay, offline. Take the last 15 first-parent release commits on
     `origin/main` (`git log --first-parent --format=%h origin/main | ...` filtered to subjects
     starting with a version). For each consecutive pair, `git diff --name-only`. Score two keys
     per fixture per pair: TRACED = "would the committed map at the newer sha select this
     fixture" (any changed path in its rows, or the fixture has no rows, or the `core/fixtures`
     directory row is present and a fixture directory was added or removed in the diff);
     DECLARED = "any changed path intersects its declaration". DECLARED is EXACT for the three
     prototyped fixtures and APPROXIMATE for the mapped rest — approximate it as the fixture's
     committed map FILE rows (no directory rows, no tools). The 11 unmapped fixtures have no rows
     to approximate from and go in a THIRD column, scored under TRACED only. Report the three
     populations in separate columns, never summed. Controls: a pair whose diff is docs-only must
     select 0 under DECLARED for a fixture declaring no docs path; and a pair that added a fixture
     directory must select ≥229 under TRACED — if no pair in the 15 carries one, extend the window
     backward until a pair does, and say how far.
   - 6c. Beside the replay, the key-record baseline from 2b: the live hook staled 101 of 247
     records mid-batch. State what the declared key would have done on the same pushes if it can
     be derived; if it cannot, say that rather than estimating.

7. **THE DECISION REPORT**, `docs/poc/hermetic-decision.md`, in this order: the verdict (GO /
   NO-GO / GO-WITH-CONDITIONS, one line, first); the census counts with their derivation; the
   three fixtures and what each showed in actions 4-6; the fail-closed results per arm; the cost
   table; the sized estimate; the migration path; the optional second leg (action 8); every claim
   that could not be verified, named. The sized estimate is `fixtures × effort class`:
   - class (a): write `inputs.decl` from existing copy lines — price at the median map file-row
     count for the class;
   - class (b): re-root the fixture into its sandbox (the `ROOT=` walk at the top of 49 files is
     the pattern to replace) and declare — price per fixture by `.git` dependence;
   - class (c): legitimately whole-tree; declare `core/`, `scripts/`, `.githooks/` as directory
     inputs and accept that they rerun on most pushes — count them and say what fraction of the
     pole they are (`enforcement-map-sites` 740s, `validator-arm-selection` and
     `validator-fork-budget` are all in this class at `PIN`);
   - plus the runner itself, the hook integration (both hooks, bound by **I66** at
     `scripts/validate-enforcement-map.sh:5190`), and the consumer layout (a consumer's fixture
     root is `tests/fixtures/`, and `install.sh` copies by list).
   The migration question is answered explicitly: can traced and declared coexist per fixture?
   The proposed answer to test is YES — a fixture with an `inputs.decl` is keyed by the runner
   and one without is keyed by the map as today, decided per fixture at dispatch — and the report
   states what in `run_fixtures` would have to branch on the file's presence. The counter-argument
   the report must engage is the deriver's own header at
   `core/scripts/derive-fixture-readsets.sh:74`: when declarations were last measured, 78 of 118
   fixtures were declared nowhere and the 40 that were declared 1-3 paths while reading 5-31. The
   hermetic proposal differs because an undeclared read FAILS instead of skipping blind; that
   defence holds only if action 5 held, and the report says whether it did.

8. **OPTIONAL SECOND LEG, only if actions 3-7 are complete and the operator has not stopped
   you:** measure whether shipped scripts reach files only through a small helper set. Count the
   raw `find`, `source`, `.`, and `ls` sites in `core/scripts/*.sh` (38 `find` and 74 `source`/`.`
   sites by a loose grep at `PIN` — a floor, since `grep` cannot see a path built by
   concatenation), list the helper functions they could route through
   (`ai_dlc_resolve_root` at `core/scripts/validate-provenance-block.sh:138` is one), and estimate
   the validator that would refuse a raw site. This leg produces a paragraph in the report, not
   code.

9. **AFTER THE REPORT IS WRITTEN, BEFORE YOU STOP: re-derive this file's own RESUME block.**
   Re-run the derive block, replace the figures above with the ones the clone returns now, replace
   the "State at authoring" paragraph with what was built and where, and turn `### NEXT ACTIONS`
   into what a NEXT session owes (nothing, if the operator has ruled; the refactor plan, if the
   ruling is GO). Run `bash scripts/validate-plan-shape.sh docs/plans/hermetic-fixtures-poc.md`
   and fix every ERROR. Commit the plan, the report and `docs/poc/hermetic-census/` on the docs
   branch. Do not commit `scripts/poc/` unless the operator asks for it; describe it in the
   report and leave it in the clone.

10. **PUBLISH, ONCE, AFTER THE GATE.** The gate: `git ls-remote --heads origin main` must return
    a sha that CARRIES 0.745.0 — `git log -1 --format=%s <sha>` starts with `0.745.0`, or
    `git merge-base --is-ancestor 67eae401 <sha>` succeeds — against the control that 0.744.0
    (`60b467dc`) is an ancestor of it. If `origin/main` does not yet carry 0.745.0, a batch-204
    push may be in flight: ask the operator, and do not push until they answer. Then
    `git push -u origin docs/hermetic-fixtures-poc` from the clone, once, and confirm
    `git ls-remote --heads origin docs/hermetic-fixtures-poc` is non-empty against the control
    that a made-up branch name returns empty. A green hook is not a landed push.

11. **FRESH-RESUME CHECK.** Merge the docs commit (merges are preapproved by standing ruling).
    Then make a fresh clone of `origin/main` and read this plan there as a stranger would, re-run
    the derive block there, assert the numbered action list names nothing already shipped on
    `origin/main`, and run `bash scripts/validate-plan-shape.sh` there as the floor. If it fails,
    fix and repeat from action 9.

12. **HAND THE PLAN TO A LOCAL AI-DLC SESSION, THEN STOP.** `ListAgents`; if a local `ai-dlc-*`
    session is found (never a `graph-*` one), `SendMessage` it exactly
    `READ and FOLLOW docs/plans/hermetic-fixtures-poc.md` and nothing else. A `REFUSED:` reply
    advances to the next untried session, idle ones first; silence does not. Once a session
    accepts, this session has no further work and communicates no further with it. If none is
    found, there is nothing further to do.

### Ping the operator

Report to the operator on every question, every decision, and on completion including an early
stop. Specifically: when the three fixtures are chosen (action 3), when action 5a returns anything
but FAIL (that is the NO-GO finding and the operator decides whether the PoC continues), before
the push in action 10 if `origin/main` does not carry 0.745.0, and when the decision report is
written. Present a stall as choices with a marked recommendation. Never narrow the scope on your
own authority: if an action cannot be completed, say what blocked it and deliver the rest.

### Done when

1. `docs/poc/hermetic-census/02-census.tsv` has one row per `core/fixtures/*/run.sh` at `PIN`,
   the class column sums to that count, and the two named controls land in their classes.
2. The runner ran all three fixtures to PASS in a sandbox under `env -i` — for the (b)
   fixture, PASS after a recorded re-root whose diff is in the report — and the sandbox
   contained no path outside the declaration plus the fixture's own directory plus
   `core/fixtures/lib/` — asserted by listing the sandbox, not by reading the runner.
3. Action 5a reported FAIL on all three (or the report names which did not and calls the verdict
   NO-GO for that reason); 5b's decoy was absent from the sandbox with its add-to-declaration
   control present; 5c reported a live-tree read count for each of the three with the tracer
   named.
4. The cost table carries copy and run medians with load beside each, and the replay reports
   TRACED against DECLARED per release pair with the exact-3 and approximate-243 populations in
   separate columns, with the docs-only control pair scoring as stated.
5. `docs/poc/hermetic-decision.md` opens with the one-line verdict, carries the sized estimate as
   `fixtures × effort class` with the class counts from criterion 1, answers the coexistence
   question, and engages the deriver's header argument.
6. This file's RESUME block has been re-derived after the report (action 9), the plan validator
   is green on it, and the docs branch is on origin (action 10) after the 0.745.0 gate.

The observation point for criteria 1-5 is the clone at `PIN`; nothing in this plan consumes its
own subject, so no criterion moves between being satisfied and being read.

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
