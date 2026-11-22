---
name: ai-dlc-update
description: "Reconcile upstream AI/DLC distribution changes into a diverged consumer project via a base-aware semantic three-way merge (the distribution→consumer pull path). Run bare for a dry-run report, or with `apply` to reconcile and open the update PR, which the operator merges. Prefix either with a distribution ref (`<ref>`, `<ref> apply`) to stop short of upstream HEAD — needed when the self-update gate reports SELF-UPDATE-DEFER and names a SELF-UPDATE-SAFE-STOP ref, because a deferred machinery slice lands after the classify that would have used it. Run with `untangle` (or `untangle apply`) for the one-time Phase-2 core/extensions/overrides migration on a still-tangled consumer. Use when the user says \"ai-dlc-update\", \"pull upstream\", \"update ai-dlc\", \"reconcile with distribution\", or \"untangle\"."
---

# AI/DLC Update — the distribution→consumer pull path

You are the AI/DLC **update** orchestrator. Your job is to bring upstream
distribution changes into THIS consumer project **without destroying the
consumer's divergence** — a base-aware semantic three-way merge, not the
blunt overwrite `install.sh` performs.

This is the third skill of the lifecycle triad: **setup** (onboard) ·
**ai-dlc** (operate) · **update** (reconcile). It runs on the consumer side
because it writes the consumer.

## HARD CONSTRAINT — self-contained

This skill and its reconcile engine MUST be self-contained. They read ONLY:
- their own files under `.claude/skills/ai-dlc-update/`,
- `git` (shelled out),
- the consumer's `.ai-dlc-version` stamp.

They MUST NOT read or depend on the consumer's PIPELINE rulebook
(`.claude/skills/ai-dlc/SKILL.md`, `steps/*.md`, `team-roles/*.md`). This is
what makes the bootstrap drop-in (§6.2 of the design spec) safe at ANY
divergence: a net-new directory that collides with nothing and needs nothing.
If you ever feel the urge to read a pipeline step to "understand the rules",
STOP — you don't; you diff text and classify it.

## The three inputs (three-way merge)

- **base**  = distribution `core/` at the `commit` recorded in the consumer's
  stamp. The last upstream rulebook content this consumer received.

  **Stamp schema (`.claude/.ai-dlc-version`, `v0.17.0+`):** two independently
  advancing versions —
  ```
  version: <rulebook ver>      # core/rulebook merge-base = the PULL BASE (this)
  commit:  <sha>               # advanced only by a rulebook apply (step 7)
  skill_version: <tool ver>    # the ai-dlc-update tool itself
  skill_commit:  <sha>         # advanced by the autonomous self-update (step 2)
  installed_at: <ts>
  upstream: <git ref>          # distribution URL (preserve on every re-stamp)
  ```
  `base` = the `commit` field (rulebook merge-base). Legacy stamps are single-line
  `X.Y.Z @ <sha>`: read `<sha>` as `commit`, `X.Y.Z` as `version`, treat
  `skill_version` as unknown; the next re-stamp/self-update rewrites the stamp in
  the schema above. Never drop `upstream`/`installed_at` when re-stamping.
- **theirs** = distribution `core/` at the **target ref**, which the operator may
  name (see *Invocation* below). Default: the private clone's fetched upstream
  `main`, as a full sha (step 1).

  **Every rev-path below writes `"${theirs}:<path>"` BRACED, and the braces are
  load-bearing.** This skill runs in the operator's shell, which is zsh, and there a
  bare `$theirs:core/...` applies a history modifier that eats the colon plus the
  character after it: `core/`, `scripts/`, `templates/` and `tests/` all mangle while
  `docs/` does not, so a read-through of the unbraced form looks fine. Quoting does not
  fix it; only the braces do. Unbraced, git either reports the ref absent or resolves
  the truncated name and answers confidently about a DIFFERENT file, and a `>` redirect
  on the same line still creates its target as the 0-byte file the next step reads.
  Keep the braces when you retype one of these commands.
- **ours**  = the consumer's live tree (`.claude/…`, plus `scripts/` for
  `core/scripts/…`).

## Invocation

```
ai-dlc-update                     dry-run report to upstream HEAD
ai-dlc-update apply               reconcile to upstream HEAD
ai-dlc-update <ref>               dry-run report to <ref>
ai-dlc-update <ref> apply         reconcile to <ref>
ai-dlc-update untangle [apply]    one-time Phase-2 migration (unaffected by <ref>)
```

`<ref>` is anything the DISTRIBUTION repo resolves — a sha, a tag, a branch, a full 40-hex
sha. It sets `theirs` and nothing else; `base` still comes from the stamp.

A bare invocation is a TERMINAL dry run: steps 1-2 run as written, then `reconcile/pull.sh
dry-run` writes the report and the run ends. It asks nothing and writes nothing else. `apply`
is the full run: steps 1-2, the step-6 checks, then ONE `reconcile/pull.sh apply`, the rows it
hands back, `pull.sh finish` and `pull.sh deliver`. There is no approval stop between the dry run
and the apply: the operator's merge of the update PR approves everything the pull decided.

**Stopping short of HEAD.** When step 2's gate returns `SELF-UPDATE-DEFER`, the deferred
machinery slice lands only with the gated apply, after the report was rendered by the engine
the pull was going to replace. Every `DEFER` carries a `SELF-UPDATE-SAFE-STOP` row naming a
release whose slice IS machinery-only; take the ref from that row, pull to it, then pull the
rest. That row acquits itself ("SPLIT BUYS NOTHING HERE") only on a run whose carry arm reached
a clean decision: a `SELF-UPDATE-CARRY` or `SELF-UPDATE-UNDECIDED` row withholds the acquittal.

**`<ref>` is validated before use — all four, and the failing one is named.** It resolves in
the **distribution** repo; `base` is an ancestor of it; it is reachable from the distribution's
default branch; it is not equal to `base`. `reconcile/pull.sh resolve` runs the four and prints
`REFUSED resolve <check> rc=2` for the one that failed. A refused `<ref>` STOPS the run; never
fall back to HEAD.

`base` and `theirs` are fetched from the distribution git repo. `ours` is the working tree.

## Path mapping (core/ → consumer)

<!-- BEGIN GENERATED: path-mapping — source: reconcile/preclassify.sh map_consumer() -->
DERIVED from `map_consumer()`. Do not hand-edit: run `render-path-mapping.sh --write`.

| core path | consumer destination |
|-----------|----------------------|
| `core/scripts/<x>` | `scripts/ai-dlc/<x>` |
| `core/fixtures/<x>` | `tests/fixtures/<x>` |
| `core/ci-templates/<x>` | `.github/workflows/<x>` |
| `core/git-hooks/<x>` | `.githooks/<x>` |
| `core/<x>` | `.claude/<x>` |
| `<anything else>` | `<unchanged>` |

First match wins, so the rows are in the order `map_consumer()` tests them: the
specific subtrees are decided before the `core/` catch-all reaches them.
<!-- END GENERATED: path-mapping -->

## Divergence taxonomy — the classifier's output buckets

Every consumer block that differs from upstream is one of:

| Bucket | Meaning | Pull action |
|--------|---------|-------------|
| **rewording** | same concept, different prose; already-upstream in substance | take theirs (drop the consumer rewording) |
| **domain-local** | consumer machinery upstream intentionally lacks AND no core text depends on | keep ours with `push_candidate: false`; layer theirs' non-conflicting additions around it. If core text at the hook target DOES depend on it, the bucket is `un-pushed-innovation` instead |
| **un-pushed-innovation** | generalizable improvement not yet absorbed upstream — including anything core text presupposes | keep ours with `push_candidate: true`; **flag for push** (feeds the absorption arc) |
| **conflict** | both changed the same core rule incompatibly | operator adjudicates |

**Every ours/theirs claim is DERIVED, never recalled.** A bucket above is a claim about
which side holds what, and the resolution prose you write is the only place that claim
appears — no detector re-reads it. So take it from the report's **Semantic worklist
orientation** block, which `emit-report.sh` renders per CLASSIFY file with the two sides
labelled and their exclusive lines shown; where a side is truncated, run the `full:` diff
command it prints. A `DETECTOR-REFUSED  orientation …` line in place of a file's sample means
that sample was never computed, not that the side is empty: derive that file's sides by running
the diff yourself. Do not describe a side from having read the file earlier in the run.

## Procedure

**Run every long call in the background.** Step 1's push, `reconcile/self-update-gate.sh`,
`reconcile/self-update-push.sh`, `reconcile/apply.sh` and every later push (each push runs
the consumer's pre-push suite) take minutes, so issue each with `run_in_background: true` and
wait for its completion notice. Never declare a foreground `timeout` above the steering budget:
`.claude/hooks/ai-dlc-foreground-budget.sh` owns that number (`AI_DLC_STEERING_BUDGET`) and
denies the call. The steps below branch on these calls' exit statuses, and a backgrounded call
still has to deliver one: send its output to a file under your session scratchpad and print the
status last — `<call> > <file> 2>&1; echo "rc=$?" >> <file>` — then read `rc=` from that file.
Never pipe the call into `tail`, which replaces its status with its own. Scratch files go under
the session scratchpad, never a bare `/tmp/<name>` that concurrent sessions share.


### The driver: `reconcile/pull.sh`

`reconcile/pull.sh` runs the deterministic part of a pull: the render, the detectors (once per
invocation), the branch, the clean applies, the decisions record, the push and the PR. You run it
and work only what it hands back. Its header is the contract; the subcommands are:

- `pull.sh resolve <consumer> [<ref>]` — step 1's clone and ref checks: `RESOLVE dist=<path>
  base=<sha> theirs=<sha>` (exit 0), `REFUSED resolve <check> rc=2`, or `ASK upstream-url …` (exit 3).
- `pull.sh gate <dist> <base> <consumer> <theirs>` — step 2's gate: `GATE OK|DEFER|UNDECIDED`, then
  the gate's `SELF-UPDATE-SAFE-STOP`, `SELF-UPDATE-CARRY`, `SELF-UPDATE-UNDECIDED` and `SELF-UPDATE-DEFER` rows verbatim.
- `pull.sh dry-run <dist> <base> <consumer> <theirs>` — the bare invocation's report; asks nothing.
- `pull.sh apply [--carried-machinery-slice] <dist> <base> <consumer> <theirs>` — the whole apply (step 7).
  It never stamps.
- `pull.sh finish [--carried-machinery-slice] <dist> <base> <consumer> <theirs>` — the stamp, the
  only write of it on a driver pull, with the same `<base>` the apply was given.
- `pull.sh merge <dist> <base> <consumer> <theirs> <override>` — an override re-adoption merge.
- `pull.sh deliver [--whole <path>]... <dist> <base> <consumer> <theirs>` — commit, push, `gh pr create` (step 8).
- `pull.sh record <dist> <base> <consumer> <theirs> [-- <path>...]` — on a finished pull, re-records the
  named paths of the record of the pull's own writes from the work tree and nothing else; it stamps nothing.
- `pull.sh pr-body <consumer>` — the rendered PR body.

**Its lines.** `PULL run=<dir> key=<12> renders=<n>`; `REFUSED <what> rc=<n>`;
`ASK <kind> <path> <digest> <question>`; `DECIDE <kind> <path> <verdict>`; `WORK classify <path>`;
`NOTE pull-writes-recorded <n> <theirs>` (`record`, exit 0); `NOTE pull-writes-rerecorded <path>` and `NOTE deliver-dirty-whole <path>` (deliver's disclosures); `HARD <row>`; `NEXT pull.sh finish [--carried-machinery-slice] <dist> <base> <consumer> <theirs>`
(apply's last line when nothing it ran is outstanding: the next step, not a decision). **Exit** 0
done, 2 refused or usage, 3 pending (an ASK row awaits an answer, a HARD row must be resolved
before anything is written, `finish` withheld the stamp (an `advisory` row does not), or `merge` relayed a pointer-stub
refusal). A `REFUSED`
names the step that refused; clear its cause and re-run the same subcommand. Never edit the
report's `reconcile-mechanical` region or the files under `<consumer git-dir>/ai-dlc-pull/`.

**THE PULL ASKS ONLY ON CONFLICT.** The question families that ask the operator are the rows of
`reconcile/ask-families.tsv`, and only those; read that file for the list, and the driver prints
each as an `ASK` row. Answer an `ASK` row with AskUserQuestion, one question per row, whose
question line QUOTES the row's FULL 64-hex digest; a short-digest cite is not an answer, and the
driver prints `NOTE ask-short-cite` beside the re-issued `ASK` row when the record holds one. The
answer-capture hook records the answer in
`_bmad-output/operator-answers-history.md`, and that record is the only proof of an answer. Then
act on the answer and re-run the subcommand that printed the row. A typed operator message is not
that answer, and neither is a decisions row.

**Every other decision is yours or the script's, and it is RECORDED, never asked.** That covers
override drift with a clean merge, extension additivity, an in-place edit of an engine-owned file,
a red push, a ledger close-candidate, a derivation-unassessable row, a setup token given its
nearest-equivalent value, `gate_types`, a retired-fixture orphan, a check-number collision,
`model_window_needed`, and every `HARD` row's disposition. The script appends its own rows to
`_bmad-output/ai-dlc-update/pull-decisions.tsv`. Append each of yours to the same file: one line,
real tabs, six columns `kind  path  digest  decider  verdict  evidence`, `decider` = `model`; when
the file is absent write its header line first, because the PR-body renderer skips line 1.
`pull.sh deliver` renders the file into the update PR body, and the operator's merge of that PR
is the approval of every row in it.

**A decision row CARRIES the command that verified it, exactly as a step-8 defect filing does.**
Its `evidence` column names the literal command run and its decisive output line, then what you
could NOT verify. A claim about WHY a detector emitted a row
is an INFERENCE — label it or verify it. A resolution command written there is given with every placeholder resolved: a literal
`<dist>` is a path nobody can walk without guessing. Treat every recommendation as a hypothesis
and run the command that would falsify it. A decisions row records a decision; it is never an
operator answer, and it NEVER authorizes a write on its own: only `apply` on this invocation does.

1. **Resolve inputs.** Read the stamp: `base` = the `commit` field (rulebook
   merge-base), per the schema above; fall back to legacy single-line parsing if
   there is no `commit:` field.

   **`<dist>` is the update skill's private clone, never a checkout.** Run
   `reconcile/dist-clone.sh [--theirs <ref>] <consumer> <upstream> <base> <skill_commit>`,
   passing `--theirs` only when the operator named a `<ref>`. `<upstream>` is the
   stamp's `upstream:` field — the default, a GitHub URL — and a local path written
   there is the override. With no `upstream:` field, ask the operator for the upstream
   to clone from (a URL or a local path), and STOP without one. On exit 0 its stdout's
   first line is `<dist>`, a bare main-only clone in the consumer's git-dir, and its
   second is `theirs <sha>`. Pass that path everywhere `<dist>` appears below, and
   never `git -C` the operator's own distribution checkout. A non-zero exit is a STOP:
   report its `dist-clone: STOP --` line, which names the cause and the remedy, and do
   not fall back to any other directory as `<dist>`.

   **With no `theirs` argument, theirs is the clone's fetched upstream `main`, resolved to a FULL 40-hex sha, never a checkout's HEAD.**
   `dist-clone.sh` resolves it as `git --git-dir=<dist> rev-parse refs/heads/main^{commit}`
   after the fetch and prints it as its `theirs` line; a named `<ref>` resolves to its
   full sha the same way. That full sha is the `theirs` every later step and the step-2
   re-invocation receive.

   **Run it through the driver:** `reconcile/pull.sh resolve <consumer> [<ref>]` reads the stamp,
   runs that clone, applies the four `<ref>` checks of *Invocation*, and prints
   `RESOLVE dist=<path> base=<sha> theirs=<sha>`. Those three values are the `<dist>`, `<base>`
   and `<theirs>` of every later step. `ASK upstream-url` (exit 3) is the no-`upstream:` case
   above; a `REFUSED resolve dist-clone rc=<n>` carries the clone's own STOP line on stderr.

   **Git preflight — the consumer branch must be in a reconcilable state.**
   Shell to git in the consumer tree and check the current branch BEFORE the
   self-update (step 2) or any apply. This runs on EVERY invocation: step 2's
   autonomous push→auto-merge writes to `origin` even on a bare dry-run, and
   steps 6–7 cut the reconcile branch off the current branch. If the current
   branch does not match `origin`, cutting a reconcile/self-update branch off it
   and merging that to `origin` diverges local from `origin` the instant it
   merges, and the NEXT update then reconciles against a base that no longer
   matches `origin` — the repeated-reconciliation this check exists to prevent.
   - **Not a git repo** → STOP; no safe isolation (same as step 6).
   - **No remote configured** (`git remote` empty) → non-blocking note; the
     origin-sync guarantees below do not apply. Proceed — step 2 falls back to
     its commit-locally path.
     On a skill branch (the grammar in the skill-branch bullet below) there is no PR to read
     and its work has not reached the working branch: STOP, name the branch, and give the
     local merge remedy: step 8's RETURN PROCEDURE in its ABANDON form to `<cut-from>` (the
     branch it was cut from, derived from the reflog as the skill-branch bullet below
     states), then `git merge --ff-only <skill-branch>`, then `git branch -d <skill-branch>`,
     the same hand-merge step 8's local-only STOP already handed the operator. Every other
     branch proceeds as above.
   - **Detached HEAD** → STOP; there is no branch to track or return to.
   - **Current branch is a skill branch** — a name matching
     `^ai-dlc-update/([0-9]+\.[0-9]+\.[0-9]+-reconcile-|self-update-|untangle-)`, the three
     names this skill cuts (step 6's reconcile branch, step 2's self-update branch, untangle
     mode's isolate branch). This is the skill-branch grammar, defined here once and cited
     elsewhere; it reads the branch NAME only and needs no network. A branch that does not
     match makes no `gh` call here and nothing in this bullet applies to it. On a match, run
     this one command, `<b>` being the current branch, which prints one row per
     same-repository PR from it:
     `gh pr list --head <b> --state all --json number,state,baseRefName,headRefOid,isCrossRepository --jq '.[]|select(.isCrossRepository|not)|[.number,.state,.baseRefName,.headRefOid]|@tsv'`
     Then four tests, in order. (1) Any row whose state is `OPEN`: STOP with "PR #N from
     <branch> is still open: merge or close it, then re-invoke from this branch." Merging
     it in the UI, or with the literal merge command, moves no checkout; on the re-invoke
     from THIS branch the merged-PR return below makes the move. Never check out the base
     yourself; to leave the branch unmerged, name step 8's RETURN PROCEDURE in its ABANDON
     form instead.
     (2) The `MERGED` rows' distinct `baseRefName` set is exactly one branch, and that branch
     does not match the skill-branch grammar. (3) The local tip, `git rev-parse HEAD`, equals
     the `headRefOid` of one `MERGED` row.
     (4) When the reflog derivation below yields the branch this one was cut from, that
     `MERGED` row's `baseRefName` equals it; otherwise STOP naming both, before any return,
     and offer step 8's RETURN PROCEDURE to that `baseRefName` or its ABANDON form to the
     branch it was cut from, running neither; a bare re-invoke repeats this STOP, so the operator names one.
     With no matching reflog line, (2) alone decides the base, as before.
     When (2) and (3) both hold and (4) passed, run step 8's RETURN
     PROCEDURE for that PR; when it succeeds, STOP this invocation and re-invoke
     `/ai-dlc-update` with the operator's original arguments in full, under step 2's
     re-invoke rule, because the stamp, `<dist>` and this SKILL.md were all read on the
     skill branch. Anything else (no row, closed-unmerged rows only, more than one base, a
     base that matches the grammar, a tip equal to no merged head, or `gh` unavailable or
     failing) is a STOP that names the branch and every row's PR number and base, and
     returns nowhere. That STOP also checks for `.claude/.ai-dlc-applying` and says whether
     an apply is unfinished, then names the continuations and runs none of them:
     `reconcile/pull.sh finish …` as step 7's finish text gives it, step-8 delivery of
     this branch, or step 8's RETURN PROCEDURE in its ABANDON form to `<cut-from>` (the
     branch it was cut from, derived as the next sentences state) to abandon it.
     **The branch a skill branch was cut from is derived one way, here**, and steps 2 and 8
     cite it: it is `<cut-from>` in steps 1 and 8 and `<original-branch>` in step 2, and a
     remembered value is never used. Read it from HEAD's reflog, the record git wrote for
     the `git checkout -b` that cut the branch: run `reconcile/pull.sh cut-from . <skill-branch>`.
     It takes the OLDEST `git reflog --format=%gs` line that begins with `checkout: moving from `
     and ends with the fixed string ` to <skill-branch>`, compared as a string and never as a
     pattern, so the dots in a version cannot match other characters, and prints the text
     between the two, which is the branch; it prints nothing, exit 0, when no line matches.
     A nonzero exit (2 with a usage message, from an engine that predates `cut-from`) is not
     that case: STOP and name the stale engine. When
     no reflog line matches (the reflog expired or is disabled), step 1's STOPs above name
     the branch and say that its origin is unknown; steps 2 and 8 state their own fallback.
   - **Remote exists but the current branch has no upstream** (never pushed) →
     **AUTO-PUSH**: run `git push -u origin <branch>` to publish it, then proceed.
     Its commits are absent from `origin`, so a branch cut off it and merged to
     `origin` would strand them; publishing first removes the hazard. **A failed
     push is NOT fatal** (auth, network, protected branch, remote rejected): report
     the exact `git push` error and its remedy in one line, mark the branch
     **UN-SYNCED** for this invocation, and continue — see the UN-SYNCED paragraph
     below for what that state may and may not reach.
   - **Branch AHEAD of its upstream** (unpushed commits) → **AUTO-PUSH**: run
     `git push` to bring `origin` in sync, then proceed. Ahead-only means the
     remote has not moved, so this is a clean fast-forward on `origin` and the
     exact remedy the operator would run by hand. **A rejected or failed push is
     NOT fatal**: report the `git push` error in one line, mark the branch
     **UN-SYNCED** for this invocation, and continue. A rejection because the
     remote advanced between check and push means the branch is now diverged, so
     the remedy to report is the diverged one — pull/rebase, then re-invoke.
   - **Branch BEHIND its upstream** → STOP; fast-forward/pull first, so the
     reconcile runs against current `origin`, not a stale local base. (Not
     auto-resolved: a pull can conflict and is not a push.)
   - **Diverged** (both ahead and behind) → STOP; operator pulls/rebases first.
     (Not auto-resolved: a rebase/merge can conflict; a bare push would be
     rejected.)

   Detect with: `git remote` (empty → no remote); `git symbolic-ref -q HEAD`
   (fails → detached); `git rev-parse --abbrev-ref --symbolic-full-name @{u}`
   (non-zero exit → no upstream on this branch); and
   `git rev-list --left-right --count @{u}...HEAD` (prints `<behind>\t<ahead>`).
   For the two push-resolvable states (no-upstream, ahead-only) auto-push and
   report what was pushed in one line; for BEHIND/DIVERGED put the exact
   ahead/behind counts and the `git pull`/rebase remedy in the STOP so the
   operator knows what to run, then re-invoke. A branch in sync with its
   upstream — reached directly or via the auto-push — is the only state that
   proceeds to step 2's push or to `apply`. **Step 1 does not check the working
   tree**, because it runs on every bare dry-run and a dirty tree does not make a
   read-only report wrong. A dirty tree is refused for `apply` at step 6, and step 2
   never commits a path it did not write: it stages by explicit pathspec, so an
   uncommitted consumer edit is never swept into the self-update commit.
   On a skill branch, step 1's return runs the RETURN PROCEDURE, and that procedure's
   clause (c) reads the working tree for dirty and on-disk paths first.

   The skill-branch test is one more of these, evaluated before either AUTO-PUSH bullet:
   `git symbolic-ref --short -q HEAD` matched against the skill-branch grammar, with no
   network. Evaluated later, a merged skill branch whose remote ref was pruned reads as
   having no upstream, and the AUTO-PUSH would publish the deleted branch back to `origin`.

   **An UN-SYNCED branch, one whose step-1 auto-push failed on THIS invocation,
   proceeds to the dry-run only.** Step 2 DEFERS on it: it cuts no self-update
   branch, writes no slice, leaves `skill_version`/`skill_commit` where they are, and
   reports that it deferred because step 1 could not sync. Steps 3–5 run and write the
   report; `apply` is refused at step 6's re-confirm bullet, which is the one place
   this state refuses anything. A failed push wrote nothing and a deferred step 2
   writes nothing, so nothing is stranded by continuing to the report; the hazard is a
   branch cut on top of it, and steps 2 and 6 are where such a branch would be cut.
2. **Self-update — an AUTONOMOUS, self-contained commit→merge cycle (before any
   rulebook classify/apply).** You run FROM a copy of this skill inside the
   consumer; a pull can include a change to that copy, so the logic executing the
   reconcile may be stale relative to `theirs`. The skill's own files
   (`core/skills/ai-dlc-update/**` — SKILL.md + `reconcile/*`) are **upstream-owned
   tooling, overwrite-safe** — that is a DECLARATION scoped to those paths, and
   refreshing them carries no consumer-divergence risk. Therefore the self-update
   lands on its OWN cycle, **autonomously — no operator approval**, distinct from
   the operator-gated rulebook reconcile (step 8).


   **That declaration does NOT extend to the rest of the machinery set.** Machinery is
   upstream-OWNED, which is not a claim that no consumer edited its copy: a consumer-modified
   machinery path is never written by this cycle (the second subtraction below).

   **The slice.** Diff `base→theirs` restricted to **the MACHINERY set** — read
   `reconcile/setup-sites.md`'s `machinery:` list, substituting `core/scripts/ai-dlc/` →
   `core/scripts/` before matching diff paths against it — **plus the fixtures that cover THE
   CHANGED PATHS**: every `core/fixtures/<dir>/` whose `run.sh` or `seed.sh` names a machinery
   path this diff touched, and every `core/fixtures/<dir>/` the diff itself touches. Exclude,
   read AT `theirs`, any dir carrying `.dist-only` and any dir upstream does not ship at
   `theirs`; subtract every path `preclassify.sh` buckets `DIST-ONLY-SKIP`; write each fixture
   directory WHOLE, its `run.sh` included. The tooling and the fixtures that guard it move
   together, because a red derived fixture DEFERS the cycle. The gate detects the couplings a
   machinery-only slice cannot carry (an enforcement-map anchor the rulebook lacks, a fixture
   asserting on rulebook, a deleted fixture the consumer holds) and returns `SELF-UPDATE-DEFER`
   for them, so on a check-adding pull the deferral is the expected outcome.

   **Run the gate through the driver:** `reconcile/pull.sh gate <dist> <base> <consumer>
   <theirs>` runs the gate below and prints `GATE OK|DEFER|UNDECIDED`, then its
   `SELF-UPDATE-SAFE-STOP`, `SELF-UPDATE-CARRY`, `SELF-UPDATE-UNDECIDED` and `SELF-UPDATE-DEFER` rows; the gate writes
   its record exactly as when run by hand. The cycle after an OK verdict stays yours.

   **Detail on demand.** The derivation's full rules (both exclusions and both fixture terms as
   the enforcer spells them), the gate record's refusals and tolerances, and the carried-pair
   note live in `reconcile/self-update-refusals.md`. Read it when deriving the slice by hand or
   when the push wrapper or its checker refuses: read it in consecutive bounded native Read
   chunks (offset+limit) of at most 16 KB, never `ctx_*`, and re-read it on need after a
   compaction.

   **EMPTY is a CONTENT question, not a diff question — or this step never terminates.**
   `base` advances only under a gated `apply`, so after a self-update the diff still lists every
   machinery path it wrote.
   
   So drop from the slice every path whose consumer copy already matches `theirs`. Do not
   hand-roll that comparison: `reconcile/preclassify.sh` already buckets exactly this as
   `ALREADY-AT-THEIRS`. The slice is the sliced paths MINUS those.

   **Then subtract a SECOND set from the SAME call: every path whose bucket records a
   consumer divergence.** That call already returns them; reading one bucket
   and dropping the rest on the floor is the whole defect — a machinery path the consumer
   has edited comes back `BOTH-CHANGED->CLASSIFY` and was written from `theirs` anyway.
   **Key the subtraction on the CLASSIFY marker, not on that one bucket name.** Every bucket
   `preclassify.sh` sends `->CLASSIFY` is a path whose two sides diverged and which therefore
   needs an adjudication this autonomous cycle does not perform, and `BOTH-CHANGED` is only
   the modified-both-sides member of that set — the added-both-sides, upstream-deleted and
   consumer-deleted members carry consumer state too. `RELOCATE-MOVE+consumer-edited` records
   a divergence without carrying the marker, so match it as well.

   **Do NOT write those paths, and do NOT treat the subtraction as a silent drop.** Report
   each by name in one line, and carry it to the step-7 gated apply, which already emits a
   `WORKLIST semantic-merge <path>` row for it — so the path reaches the operator instead of
   being overwritten. `reconcile/self-update-gate.sh` emits one `SELF-UPDATE-CARRY` row per
   such MACHINERY path; if its set and yours disagree on a machinery path, stop and report
   that, because one of the two derivations is wrong. **A fixture path is outside that
   comparison by construction:** the gate classifies the machinery set, which holds no
   `core/fixtures/` entry, so it never emits a CARRY row for a fixture. Whether a fixture
   directory is carried is decided by the fixture-write rule in the cycle below and by
   nothing else, and that rule carries a WHOLE directory, never one file of it. A fixture
   path you carry that the gate did not name is NOT a disagreement.

   A carried path stays in the `base→theirs` diff on every later invocation, since `base`
   advances only at step 7. That is correct and is NOT the non-termination case above: it is
   a standing worklist item, reported each run and never re-attempted.

   If the slice is EMPTY after that subtraction, say so in one line and continue to step 3.

   **On a branch step 1 left UN-SYNCED, step 2 DEFERS a non-empty slice, before the gate.**
   Do not run `reconcile/self-update-gate.sh`, do not cut the self-update branch, do not write
   the slice, and do not advance `skill_version`/`skill_commit`. Report in one line that step 2
   deferred because step 1 could not sync the branch, then continue to step 3. The slice is
   carried to the gated apply, and step 6 refuses that apply on this state, so nothing records
   the slice for later: the next invocation, after the operator syncs the branch, derives it
   again. A local commit here is the orphan `PC-S308` describes (a stamp advanced on a commit
   that never merges), left checked out on a branch the next invocation's step 1 would publish
   without the gate. No self-update landed, so the re-invoke rule below does not fire and
   steps 3–5 run on this invocation's logic.

   If NON-EMPTY, **first run `reconcile/self-update-gate.sh <dist> <base> <theirs> <consumer>`.**
   The machinery slice includes `core/scripts/*`, and the consumer's own `.githooks/pre-push`
   INVOKES several of those scripts — so this cycle can install a check that then fails the very
   push it is making, on layer state that predates the pull and whose remedy is rulebook-side work
   this step deliberately does not do. A failed push discards the
   cycle rather than committing locally: a local commit would strand an orphaned
   local branch whose push is permanently blocked, with a
   `skill_version` advanced on a commit that would never merge;
   see the push-failure paragraph
   below.

   - On `SELF-UPDATE-DEFER` or `SELF-UPDATE-UNDECIDED`: **do NOT cut the branch and do NOT push.**
     Report the rows, and carry the machinery slice into the step-7 gated apply so machinery and
     rulebook land on ONE branch — the operator fixes the layer state there, and that is the only
     ordering in which the pre-push gate can go green. Say in one line that step 2 deferred and
     why, and **advance `skill_version`/`skill_commit` at step 7 rather than here — by passing
     `--carried-machinery-slice` to `pull.sh apply` and `pull.sh finish`; the finish writes the
     pair with the stamp.** That flag is the whole mechanism; do NOT set the two fields by hand, and do not
     read step 7's "preserve them" as overriding this. The two instructions describe different
     runs and the flag is what tells them apart — see step 7's re-stamp bullet.
     **The gate wrote `_bmad-output/ai-dlc-update/self-update-gate-<ts>.md` on this verdict too.**
     Carry that record to the step-7 gated apply and commit it there with the machinery slice.
     `pull.sh gate` records its path in the pull's artifacts, so `pull.sh deliver` commits it with
     the pull's other writes; on the manual path, the record reaches that commit only because the
     agent put it there.
   - On `SELF-UPDATE-OK`: proceed autonomously as below.
   - `SELF-UPDATE-CARRY` rows are ADVISORY and accompany any verdict, OK included. Each names
     one machinery path the consumer has diverged on. They do not stop the cycle; they remove
     paths from it. Report every one, write none of them, and carry each to the step-7 gated
     apply. A carry row and an OK verdict together mean "self-update the rest, hand this path
     to the operator" — the case this step had no disposition for.

   **THE APPROVAL ARTIFACT FOR THIS AUTONOMOUS CYCLE IS THE GATE RECORD, AND IT IS THE ONLY
   ONE.** This cycle cuts a branch, writes the machinery slice, pushes and auto-merges with no
   operator gate, only when step 1 reached sync (on an UN-SYNCED branch step 2 defers and
   writes nothing), so nothing outside the operating agent's own narration records the decision that
   permitted the write. The gate now writes
   `_bmad-output/ai-dlc-update/self-update-gate-<ts>.md` — its verdict, the rows it emitted and the
   range it classified.
   **Commit the gate record in the self-update commit**, so the auto-merged PR carries the evidence
   of its own approval rather than a claim about it.

   **THE ORDER IS GATE, THEN WRITE, THEN COMMIT, THEN PUSH, AND THE GATE RUNS ONCE.** Run
   `self-update-gate.sh` BEFORE writing anything, on the tree as the operator left it; write the
   slice; commit it; push through the wrapper, which checks the record and then runs the
   consumer's pre-push hook ONCE — that hook run is the self-update's only fixture run. There is
   no separate covering-fixture run before the commit. The checker accepts an input whose content
   is now what this pull ships — that is the slice just written — and refuses one that is neither
   the recorded content nor `theirs`. **Never re-run the gate after the write to refresh a
   record.** A gate run on the written tree compares each incoming script with a copy of itself,
   so it reports OK for the one reason that means nothing, and the checker refuses such a record
   as `PRE-WRITTEN`.

   If NON-EMPTY and the gate says OK:
   - **Run the self-update cycle autonomously:** cut a dedicated branch
     `ai-dlc-update/self-update-<theirs-version>-<ts>`, write from `theirs` — each file as
     `git -C <dist> show "${theirs}:<path>"`, never a read of a working tree — **only the paths
     that diff names AND that survived both subtractions above** — never a path carried by a
     `SELF-UPDATE-CARRY` row — each at the consumer destination `map_consumer()` gives it, and
     `tests/fixtures/<dir>/` for the covering fixtures, each directory WHOLE or not at all
     (the fixture-write rule below) — never the derived set per
     directory, **update the stamp's
     `skill_version`/`skill_commit` to `theirs`** (rewrite the stamp in schema,
     preserving `version`/`commit`/`installed_at`/`upstream`), then commit
     (`chore(ai-dlc-update): self-update <base-skill-ver> → <theirs-ver>`) — **including the
     gate record, which is this cycle's approval artifact** — and push
     **through the wrapper, never a bare `git push`**:
     `bash reconcile/self-update-push.sh <consumer> origin <self-update-branch> _bmad-output/ai-dlc-update/self-update-push-<ts>.md <dist> <base> <theirs>`
     (`origin` is the remote step 1 synced against; the fourth argument is a NEW untracked path
     the wrapper writes only on a refusal; `<dist> <base> <theirs>` are the ones the gate ran
     on). The wrapper runs the gate-record checker first and the consumer's pre-push hook second,
     once; that hook is the only fixture run this cycle makes. Exit 0 means pushed: open a PR, and
     **auto-merge (squash, delete branch)** — no operator gate.
     If you hold the advisor tool, call it in a message of its own before `gh pr merge`.
     The literal `gh pr create` and `gh pr merge` commands are in the bullet below that
     opens "After the auto-merge".
     Exit 4 (`TRANSPORT`) and exit 3
     (`HOOK-REFUSED`) are the next paragraph's two cases; exit 2 with a `GATE-RECORD-REFUSED`
     stdout line is the RED-PUSH paragraph's case below; any other exit 2 is a refusal with nothing
     pushed — a bad argument, a remote with more than one push URL, or a hook that moved the
     branch — so report its stderr line and treat it as exit 4.
     **That holds only when step 1 reached sync**: the preflight then confirmed the
     branch is in sync with `origin`, so this merge cannot strand local commits.
     This bullet is never reached on an UN-SYNCED branch: step 2 deferred above,
     before the gate. With no remote configured there is nothing to push: commit locally and
     note it. A push that fails is the next paragraph's case and never ends in a kept commit.
     Advancing `skill_version` here is what keeps the stamp an honest record
     of the installed tool version — it is bookkeeping tied to the (already
     autonomous) self-update, and never touches `version`/`commit` (the rulebook
     base stays put until a gated apply).

     **A PUSH THAT FAILS HERE DISCARDS THE CYCLE; it never keeps a local commit.**
     The wrapper separates the two ways it fails, because a hook refusal and a remote rejection
     both exit 1 from a bare `git push` with the same stderr shape and need different
     dispositions. Exit 4 (`TRANSPORT`) is a transport failure — auth, network, a remote
     rejection — after the consumer's own pre-push hook passed in the wrapper's single run.
     Exit 3 (`HOOK-REFUSED`) is that hook refusing the written tree, with nothing pushed; its
     disposition is the HOOK-REFUSED paragraph below, not UN-SYNCED. Either way a kept commit is
     the orphan `PC-S308` describes:
     `skill_version` advanced on a branch that never merges. The commit above stages ONLY the
     paths this cycle wrote,
     each named by explicit pathspec:
     the slice at its `map_consumer()` destinations, the covering `tests/fixtures/<dir>/`, the
     stamp, and the gate record. Never `git add -A` or `git add .`, which sweep an uncommitted
     consumer edit into the commit. On a `TRANSPORT` exit, in this order: report the `TRANSPORT`
     line and the push error above it in one line;
     make the next move as step 8's RETURN PROCEDURE in its ABANDON form, whose `<working>` is `<original-branch>` (the reflog-derived branch, or the branch step 1 confirmed in sync when no reflog line matches): its working-tree check runs first, the checkout on the next line IS that form's (d), run once and never as an extra step, and its (e) follows; if the check prints a line, ABANDON STOPs and so does this invocation, so steps 3–5 do not run on the self-update branch: the branch is kept and named, step 2 reports DEFERRED, and the next invocation's step 1 offers ABANDON;
     run `git checkout <original-branch>`, the branch step 1 confirmed in sync;
     list every file the self-update branch's commits touch with `git diff --name-only <original-branch> <self-update-branch>`;
     only when every listed path is in the written set above, delete it with `git branch -D <self-update-branch>`.
     If any path falls outside that set, do NOT delete it: STOP and name the branch,
     because it holds work this cycle did not write. After the delete,
     report that step 2 DEFERRED because its push failed,
     and mark the branch UN-SYNCED for this invocation exactly as a failed step-1 push does:
     steps 3–5 run and write the report,
     and step 6 refuses `apply`, because the machinery this pull ships did not land.
     `skill_version`/`skill_commit` stay where they were, because the stamp rewrite lived only on the discarded commit.
     The gate record left with that commit, so the one-line report carries the push error. The
     next invocation, after the operator fixes the push, derives the slice again.

     **On a `HOOK-REFUSED` exit the branch is discarded the same way, but the disposition is
     `SELF-UPDATE-DEFER`, not UN-SYNCED.** The consumer's own gate refused the tree this cycle
     wrote — a refusal that may predate the pull, which no differential arm of the gate can see —
     so the remedy is the operator's, at the gated apply, exactly as for a gate DEFER. In this
     order: report the `HOOK-REFUSED <rc> <phases>` line;
     make the next move as step 8's RETURN PROCEDURE in its ABANDON form, whose `<working>` is `<original-branch>` exactly as on a `TRANSPORT` exit: the checkout on the next line IS that form's (d), run once and never as an extra step; if its working-tree check prints a line, ABANDON STOPs and so does this invocation, so steps 3–5 do not run on the self-update branch: the branch is kept and named, step 2 reports `SELF-UPDATE-DEFER`, and the next invocation's step 1 offers ABANDON;
     run `git checkout <original-branch>`;
     restore the gate record from the self-update commit, through a temporary file so a record
     the branch does not hold is never truncated:
     `git show "${self_update_branch}:<path>" > <path>.restore && mv <path>.restore <path>`.
     A record the branch does not hold is already in the working tree, uncommitted, and stays
     as it is; delete the empty `<path>.restore` that the failed `git show` left;
     run the same `git diff --name-only <original-branch> <self-update-branch>` check and, only
     when every listed path is in the written set above, `git branch -D <self-update-branch>`
     (any path outside it: STOP and name the branch, as above).
     Two files now sit in the working tree UNCOMMITTED — the gate record just restored, and the
     wrapper's `_bmad-output/ai-dlc-update/self-update-push-<ts>.md`, whose
     `# probe:` lines are the hook's exit, the ref line it was fed and the tail of its output.
     Carry both to the
     step-7 gated apply and commit them there with the machinery slice, exactly as the gate's
     DEFER verdict leaves its record above; run that apply as
     `reconcile/apply.sh --carried-machinery-slice <dist> <base> <consumer> <theirs>`.
     `skill_version`/`skill_commit` stay where they were and advance with that apply. The branch
     is NOT UN-SYNCED: step 1 reached sync and nothing was pushed, so steps 3–5 run and step 6
     does not refuse `apply` on this account.

     **A derived fixture is a consumer edit when `preclassify.sh`'s BUCKET for that path says
     so, or, for a path it has no row for, under the rule below — never overwrite one that is.** Report the path, leave the file, and
     continue the cycle. Only `.claude/skills/ai-dlc-update/**` is overwrite-safe by declaration;
     a fixture is not, and the derived set's FIRST term is grepped from the fixtures rather than
     from the diff, so it names fixtures this pull does not change.
     In a directory written whole, a file with NO `preclassify.sh` row (upstream did not change
     it) is a consumer edit when its consumer copy differs from the distribution blob at `base`
     AND at the stamp's `skill_commit`, or when the consumer added it (absent upstream at both
     refs); such a file holds its whole directory back under the ONE-UNIT rule below.
     `preclassify.sh` buckets only the `base`..`theirs` diff, so it never classifies such a file.

     **A FIXTURE DIRECTORY IS ONE UNIT: if ANY path under a derived fixture directory is held
     back as a consumer edit, write NONE of that directory and carry ALL of it** to the step-7
     gated apply, every path the diff names under it, reported by directory in one line. Never
     write the upstream-only files of a directory whose other file you held back. Its `run.sh`,
     `inputs.decl`, `tools.decl`, `seed.sh` and `lib.sh` describe one test, and a new `!`
     REQUIRED line in an incoming `inputs.decl` beside the consumer's older `run.sh` that never
     consumes it is a fixture the consumer's own pre-push refuses with `required_missing=1`.
     Measured on the reference consumer's `0.760.0` self-update: `artifact-path-conformance`'s
     `run.sh` was held back as BOTH-CHANGED, its upstream-only `inputs.decl` was written, and
     the push refused that fixture. This is a WRITE rule only: a carried directory keeps the
     consumer's untouched copy, which the push's hook then runs like any other consumer fixture.
     This rule does not touch `GATE_CARRY_STATE`, which the gate derives from
     machinery CARRY rows alone; a fixture directory carried here is never a gate CARRY row.
     **This prose takes effect on the invocation AFTER a landed self-update**: the agent reading
     it during the pull that delivers it is still reading the installed copy.

     **DO NOT DERIVE THE VERDICT BY COMPARING REFS. `preclassify.sh` has already answered this,
     for these paths, in this run.** This paragraph, and the ref-comparison passage
     below it, bind only paths `preclassify.sh` buckets; a path it has no row for is decided by
     the undiffed-file rule above. Take its bucket and apply the SAME subtraction that
     `reconcile/self-update-gate.sh` applies in the arm guarding its `SELF-UPDATE-CARRY` row —
     grep that token to find it. That arm is authoritative for which buckets mean consumer
     divergence, and its own header says keying on anything narrower names a set the downstream
     half does not agree with. Read the arm; do not restate it here and do not re-enumerate the
     buckets, which have no single owning declaration.

     **A SECOND DERIVATION OF THIS QUESTION RETURNED THE OPPOSITE VERDICT, AND THE TOOL WAS
     RIGHT.** Measured on the reference consumer, in ONE invocation: `preclassify.sh` bucketed
     four derived fixtures `ALREADY-AT-THEIRS` while a hand-rolled ref comparison performed under
     this step called all four CONSUMER-EDITED. The suppression was never missing —
     `at_self_update()` was present in the installed copy throughout; it was BYPASSED by the
     second derivation that this step does not call for. For a path `preclassify.sh` buckets, a
     ref comparison is wrong here in the direction
     that REFUSES a legitimate write, and it is wrong on every split stamp, which is the normal
     state after any self-update and which this cycle itself CREATES.

     `at_self_update()` is an internal function of `preclassify.sh` with no entry point of its
     own, so it cannot be called from here. Its answer reaches you as the bucket; that is the
     only channel, and it is enough.

     **A RED PUSH LEAVES AN UNPUSHED LOCAL COMMIT, AND THAT IS RECOVERABLE.** There is no
     covering-fixture run before the commit: the consumer's pre-push hook, run once by the
     wrapper, is the gate, and a refusal by it or by the wrapper's gate-record check pushes
     nothing. So a red push leaves exactly one thing behind, the self-update commit on its own
     branch, and the branch discard above removes it. A `GATE-RECORD-REFUSED` exit 2 — no
     matching OK record, a record whose inputs moved or that was taken on the written tree, or a
     commit that wrote a `.dist-only` fixture directory or one without a `run.sh` it ships (each a
     `GATE-RECORD:` line on the wrapper's stderr and a `# probe:` line in its record) — takes the
     HOOK-REFUSED paragraph's sequence and disposition exactly, `SELF-UPDATE-DEFER`, with the
     wrapper's record carrying the checker's lines where the hook's would be. Report the
     `GATE-RECORD-REFUSED` line instead of a `HOOK-REFUSED` one. Never fix a record refusal by
     re-running the gate on the written tree: that record is `PRE-WRITTEN` by construction.

     **An `UNDIFFED-OVERWRITE` refusal has a sanctioned remedy that lands the cycle** and
     supersedes the disposition above for that tag only. The commit overwrote a consumer-authored
     file that upstream did not change. For each directory the `GATE-RECORD:` line names: restore
     it from the parent commit with `git checkout HEAD^ -- <dir>`, `git rm` any file the commit
     added under it, run `git commit --amend --no-edit`, and re-run the push wrapper with a NEW
     `<out>` path. A re-run with the same `<out>` refuses `already exists`; that is not a
     transport failure. The first `<out>` record stays untracked, is never staged into the
     amend, and is carried to step 7 like the HOOK-REFUSED record, where the next gated apply
     commits it. The restored directory is
     carried whole to the step-7 gated apply under the ONE-UNIT rule. This re-runs the wrapper,
     not the gate, so the rule against re-running the gate on the written tree still holds. The
     HOOK-REFUSED sequence with `SELF-UPDATE-DEFER` remains a safe fallback.
   - **After the auto-merge, return the checkout before the re-invoke.** The auto-merge is
     `gh pr merge <n> --squash --delete-branch=false --match-head-commit <sha>`, where `<sha>` is
     `git rev-parse <self-update-branch>`, so the merge takes exactly the commit the wrapper
     pushed; `--delete-branch=false` means gh moves no checkout and asks nothing. Then run step 8's
     RETURN PROCEDURE for that PR. With no remote configured there is no PR: run step 8's
     RETURN PROCEDURE in its ABANDON form to `<original-branch>`, then
     `git merge --ff-only <self-update-branch>` (always a fast-forward, because the branch
     was cut from `<original-branch>`), then `git branch -d <self-update-branch>`. A STOP
     from the procedure stops the re-invoke too: report that the self-update merged but the
     checkout did not return, with the procedure's STOP line. When the PR is not `MERGED`
     (a merge queue or `--auto` leaves it open), report that the self-update is not merged,
     never that it landed, and do not re-invoke.
     The PR is opened with `gh pr create --base <original-branch>`; without `--base`, gh
     targets the repository's default branch. `<original-branch>` is the branch the
     self-update branch was cut from, derived from HEAD's reflog as step 1's skill-branch
     bullet states; with no matching reflog line it is the branch step 1 confirmed in sync
     on this invocation, which is the prior behaviour. The return after the merge STOPs
     when the PR's `baseRefName` is not `<original-branch>`, naming both.
   - **Then STOP this invocation and re-invoke `/ai-dlc-update` automatically —
     do NOT ask whether to.** The self-update landed, but THIS invocation is
     still executing the PRE-update logic — its reconcile/classify/apply behavior
     is stale, and an in-flight agent cannot hot-reload its own instructions. So
     do NOT proceed to step 3 on stale logic. Instead: report in one line that
     the self-update landed (merged PR ref) + what changed (`reconcile/` — the
     engine — vs prose/docs), then **immediately re-invoke the `ai-dlc-update`
     skill (Skill tool), carrying the operator's original arguments IN FULL** — a
     bare run re-invokes bare (fresh dry-run), an `apply` run re-invokes `apply`,
     and **a run that named a `<ref>` re-invokes with that same `<ref>`**. The
     fresh invocation loads the updated logic and runs the reconcile on it.

     **The `<ref>` the re-invocation carries is the resolved FULL 40-hex `theirs` sha
     from step 1, whether or not the operator named a ref.** The fresh invocation's
     step 1 runs the NEW step-1 text and may read a different `<dist>` than this one did
     (on the pull that delivers `dist-clone.sh`, this invocation read the old dist); a
     branch name or `main` would re-resolve there and could name a different commit,
     while the full sha names the commit this invocation's gate approved. Its step 1
     passes the stamp's `skill_commit` to `dist-clone.sh` as a `<ref>`, so a
     `skill_commit` the new dist cannot resolve STOPs with a named cause.

     Dropping the `<ref>` on re-invoke silently retargets the pull at HEAD, which
     is the one thing the operator ruled out by naming a ref — and it would do it
     at the exact moment the split-pull remedy is being executed, turning a
     deliberate two-step back into the single bundled pull it was working around.

     Re-invoking is the default and needs no confirmation: an operator who just
     updated the tool wants to run its latest iteration, and the re-invocation is
     the only way to execute the fresh logic — there is no reason to update the
     tool but not re-run it. Do NOT continue this run on the stale logic (silently
     proceeding on stale logic is the exact defect this stop prevents). The one
     case that returns control to the operator: if the re-invocation cannot be
     issued automatically in this harness, say so in one line and tell the
     operator to run `/ai-dlc-update` themselves — never fall through to stale
     logic. This applies even when the following reconcile would be empty.
3. **Detect — the driver runs every detector once; you never chain them by hand.** One render
   of `reconcile/emit-report.sh` inside `pull.sh dry-run` or `pull.sh apply` runs, on one
   pre-write state: the mechanical pre-classification (`reconcile/preclassify.sh`), the template
   pre-classification (`--templates`), layer drift (`reconcile/layer-drift.sh`), unregistered core
   drift (`reconcile/unregistered-drift.sh`), the consumer-catalog collisions and the newly
   unloadable extension checks, the push-candidate ledger re-verify (3f below) and the predicate
   reclassification. Their rows land in the report's `BEGIN/END GENERATED: reconcile-mechanical`
   region, and the union gate and `apply.sh`'s pre-write calls answer from that same render while
   its fingerprint holds. Do NOT hand-verify overrides with ad-hoc `git diff` calls and do not
   re-run a detector to "check" the region: a hand check is what let overrides whose `base_sha`
   named the consumer's own repo go unseen.

   **What each row means and what you do with it** — every status of steps 3-3e and 3g, each
   `HARD-*` row's disposition, the per-bucket apply actions and the post-write gates' rows —
   lives in `reconcile/detector-rows.md`. Read the section for a row when the driver hands you
   that row: read it in consecutive bounded native Read chunks (offset+limit) of at most 16 KB,
   never `ctx_*`, and re-read it on need after a compaction. Two `HARD-*` statuses carry a layer
   clause and are stated here, because this file is their clause's home:

   - `HARD-LAYER-ADJUDICATION-MISSING` [LC-A1] → a row of a clause at `level: ADJUDICATED` has no
     recorded verdict in `_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl`
     under the `subject_digest` the row carries. **Blocks `apply`.** The remedy is to make
     the judgement and write it down, not to widen anything. Step 7 has the record shape.
     The row carries the `clause` id as well as the `subject_digest`, and BOTH are copied
     from it rather than derived — a wrong clause is well-formed, passes the schema, and
     lands in an append-only register. A record clears only when it also carries
     `read.entry_line` and `read.core_line` and both are found; one that does not is named in
     the row as `[no read evidence]`, `[read.entry_line not in the entry]` or
     `[read.core_line not in the <clause> core text]`.
   - `HARD-REGISTER-CONTRADICTION` [LC-A2] → that register states two different verdicts under one
     key and the later record declares no `supersedes` plus `reason`. **Blocks `apply`**,
     because a lookup would otherwise answer with whichever record was read last.

3f. **Push-candidate ledger re-verify — the CLOSE path.** Run
   `reconcile/ledger-reverify.sh <dist-repo> <base-sha> <consumer-root> <theirs-ref>`.
   Step 8 APPENDS to the ledger; nothing ever closed it, so an entry upstream adopted stayed
   open forever and could be re-pushed. For each OPEN entry carrying a `verify:` line, this
   re-runs the entry's own receipt against `theirs`; an OPEN id-keyed entry with NO `verify:`
   line gets the naming query alone and emits only `NAMED-UPSTREAM(-AMBIGUOUS)`. An entry is a
   `- **…**` bullet, a column-0 `**<id>** — …` record, or a `##`–`######` heading. The pull
   that delivers this engine shows those rows in its own report unless the gate returned
   `SELF-UPDATE-DEFER`; then they first appear on the following pull, or at the
   `SELF-UPDATE-SAFE-STOP` ref:
   - `CLOSE-CANDIDATE` → the innovation is now present upstream / the defect no longer
     reproduces. **Report-only; never blocks `apply`** (a close touches no core and cannot
     lose data). The operator confirms and annotates at step 8 — the tool never edits the
     ledger, exactly as `HARD-CORE-DRIFT-ABSORBED` never reverts a file itself.
   - `STILL-LIVE` → stays open, filtered from the report.
   - `NAMED-UPSTREAM` → upstream's own commit history NAMES this entry's id. Emitted **in
     addition to** the receipt's verdict, never instead of it: a receipt can be structurally
     incapable of ever closing (anchored on a token present at both refs, an inverted verb, or
     `verify: manual`), and then re-running it forever produces a confident wrong answer. The
     id is the one signal a rewording cannot defeat, because it is the join key the ledger, the
     report and the §8.1 fan-in already use. `STILL-LIVE` + `NAMED-UPSTREAM` on one entry is
     the highest-value pair this tool prints: the entry is absorbed AND its receipt is wrong.
     **Not auto-closable** — step 8 closes `CLOSE-CANDIDATE` rows only, so this needs no
     exception. It is not *unclosable*: the row instructs an annotation, and a **line-leading**
     close marker in an entry makes `ledger-reverify.sh` skip it from the next run on.
     Write the close **in a bold span** — on its own line, or in the entry title's bold — or the
     entry becomes skipped-but-unarchivable: invisible in every future report and never filed.
     `ledger-rotate.sh` reports that set. **No version is required**; a close that genuinely has
     none (a withdrawal, an absorption predating `base`, a rejection adjudicated by date) archives
     on its own terms, and inventing a version to satisfy the rotator is the defect pointed the
     other way. Rotation's grammar is `ledger-reverify.sh`'s own close rule with the bold span made
     mandatory, derived by `reconcile/lib.sh`'s `ledger_archive_awk()`, so the two tools cannot
     honour different token sets.
     Read it as "upstream named it", not "upstream took it": a commit can name an id to record
     a rejection or a split. Confirm which, then re-anchor or drop the stale receipt.
   - `NAMED-UPSTREAM-DOCS-ONLY` → upstream's history names this entry's id, and **none** of the
     naming commits changes a path under `core/` or `templates/` — the two trees a consumer
     installs — or cuts a release (changes `VERSION`). A plan, a review or a ledger drain that
     cross-references an id matches the message search exactly as a fix does; this kind keeps
     the row and its full sha list but says the naming is not evidence of an absorption. **Not
     a close on its own** — read the commits for a withdrawal or a split, then read the entry's
     subject at `theirs`, because a fix that never names the id is invisible to this search.
     A release commit that names the id counts as reaching even when it changes only
     `CHANGELOG.md` and `VERSION`: that is the release a consumer pulls, and its parent usually
     carries the fix. The converse does not hold: a commit that touches `core/` can still merely
     mention an id, so a plain `NAMED-UPSTREAM` remains "upstream named it", never "upstream
     took it".
   - `NAMED-UPSTREAM-OFF-SUBJECT` → upstream's history names this entry's id and the naming
     commits change installed paths, but **none** of them changes any of the entry's own
     `theirs_has` / `theirs_lacks` receipt paths, which the row names. A naming commit that
     changes `VERSION` is judged over its whole release span — every commit after the previous
     `VERSION` change up to it — so a release whose fix sits in an unnamed parent still counts
     as touching. A consumer-layout receipt path is resolved by unique basename at `theirs`;
     an entry with no path receipt, or with any path that does not resolve, keeps
     `NAMED-UPSTREAM`. **Not a close and not a refusal**: the id may already have been
     dispositioned by an earlier release with this naming a later mention, or the fix may sit
     on a path the receipt does not name. Read the commits, then the entry's subject at
     `theirs`. A plain `NAMED-UPSTREAM` with a path receipt means a naming commit changed the
     receipt's FILE — never that it changed the receipt's substring.
   - `NAMED-UPSTREAM-SIBLING-ATTRIBUTED` → a naming commit changes the entry's receipt file,
     but on every changed block of that file **none** of the entry's own receipt substrings is
     on a changed line, while a **sibling** entry the same commit names by its full slug has its
     receipt substring there. The row names the sibling(s). Every naming commit is judged, a
     release over its span, and the sibling must be an OPEN entry in the live ledger — a closed
     or archived sibling attributes nothing, so this row reads the plain kind once the sibling
     is annotated, and never depends on the archive. **Not a close
     and not a refusal**: a release that fixed the sibling and cross-referenced this entry reads
     this way, but so does a fix that left this entry's anchor stale. Read the commits and the
     sibling's entry, then this entry's subject at `theirs`.
   - `NAMED-UPSTREAM-CITED-ONLY` → upstream's history names this entry's id, and **every**
     naming commit names it only on a body line reading exactly `Not-discharged: PC-S<n>` or
     `Not-discharged: PC-S<n>-<SLUG>` (SLUG in the id class `[A-Za-z0-9_.-]`) — the form a distribution release uses to cite an entry
     it did NOT discharge. The row keeps the full sha list and is **not an absorption claim**.
     Read the commits for a rejection, a withdrawal or a split, then read the entry's subject
     at `theirs`. A commit carrying both that line and an ordinary mention of the id still
     reads `NAMED-UPSTREAM`; commits older than the form read as they always did.
   - `NAMED-UPSTREAM-AMBIGUOUS` → upstream's history cites this entry's SPRINT prefix
     (`PC-S<n>`), and the commit does not say which entry it means. One row per prefix, keyed on
     the prefix, emitted however many OPEN live entries carry it — one included; the count in
     its detail is of those open entries. The row names EVERY citing commit, newest first, and says when none of
     them changes `core/` or `templates/`. **Deliberately NOT attributed, not even to a lone
     carrier.** Upstream writes the short id, not the full slug — measured against it at
     0.328.0, the slug search found 20 of 128 entries while 20 of 29 prefixes appeared, and of
     those 20 prefixes 11 were shared. A lone carrier is a fact about what this ledger still
     holds, not about what the commit meant: the sprint may have filed others since closed or
     rotated, and attributing on that count made the row change when sprint history was
     deleted. Read the named commit and decide per entry. Like
     `NAMED-UPSTREAM`, **not closable** — it is a pointer to a reading, not a verdict.
   - `HAND-REVIEW` → the entry declares `verify: manual`. No mechanical predicate exists for
     it BY DESIGN; adjudicate the body against theirs. This is NOT an entry with no `verify:`
     line — that emits `NAMED-UPSTREAM` when upstream names its id, and no row otherwise.
   - `NEEDS-REVIEW` → the receipt is at fault. The DETAIL field opens with the cause; report
     them separately.
     - *unresolved* — the `verify:` line is malformed, its path resolves neither as given
       nor by unique basename at theirs, or an `sh` one-liner does not PARSE (the engine
       reads ONE line, so a receipt written across two arrives cut inside its quote; the row
       says MALFORMED and the receipt was never run). Correct the path or rewrite the receipt
       on one line, then re-run.
     - *vacuous predicate* — the STILL-LIVE side was never reachable: a `theirs_has`
       substring absent at BOTH base and theirs, or a `theirs_lacks` substring present at
       both. Read the body and check whether the verb is inverted. **Never drain on this
       verdict.**
     - *unfalsifiable predicate* — a `theirs_lacks` substring absent at base, at theirs, AND
       from the consumer's own tracked tree, so no adoption can satisfy it and the entry
       reports STILL-LIVE on every pull. Re-anchor it per the rule below, or declare
       `verify: manual` if the entry is a proposal nobody has built yet. **Never drain on
       this verdict.** A DETAIL reporting reachability NOT checked means unchecked, not
       clean.
     - *unreadable* — git could not READ the receipt's path or blob at theirs or at base and
       could not confirm it absent (a missing object in the distribution checkout, or an
       unresolvable ref). The predicate was not evaluated and no basename was guessed, because an
       unread blob reads exactly like an empty one. Repair the distribution (`git fsck`, re-fetch)
       and re-run; the entry is untouched. A `VERSION` at theirs that is unreadable refuses the
       whole run instead, because every close row names that version.
     - *mis-anchored predicate* — a `theirs_lacks` substring absent at base AND at theirs
       while a near-miss spelling of it is absent at base and PRESENT at theirs: upstream
       moved, and the receipt anchors on a token the fix was not written with. Re-anchor on
       the reported spelling and re-run; the spelling is never adopted automatically.
     - *mid-line receipt* — the entry has no line-anchored `verify:` line but its body carries
       `verify: <verb>` mid-sentence. The anchored grammar cannot see it (deliberately: a prose
       mention is not a receipt), so the receipt was never run and the entry emitted no row —
       indistinguishable from one with no receipt. Move it to its own line, then re-run. A
       mention inside backticks, inside a fence, inside a blockquote or inside an HTML comment
       is a quotation and is not reported; nor is an entry that also carries a real anchored
       receipt, which is not silent.
   - `ENTRY-SWALLOWED` → a line-leading `- **…**` **annotation** inside an entry body. The
     entry-boundary rule opens a new entry on any such line, so the annotation truncates the
     entry it was annotating: everything below it — **including the `verify:` receipt** — is
     attributed to the annotation, and the real entry stops emitting any row under its own id.
     A silent disappearance, and it reads exactly like an entry with nothing to report. The
     signal is the colon: an annotation is a lead-in (`- **The share:** …`) and its bold span
     ends in one, while an entry title does not. The DETAIL names the nearest id-shaped entry
     above it and says whether a receipt was captured. **Fix the ledger, not the entry** —
     re-indent the annotation so it does not start a line, or drop the bold, then re-run and
     confirm the id reappears. Report-only; it never blocks.
     **Two more causes share the status.** An id-keyed entry line INSIDE a fenced code block
     (the fence is unterminated, or it quotes an entry heading) still opens an entry, because
     hiding an id is the worse failure, and is reported with the entry it truncated; close the
     fence or indent the quoted line. A fence still open at the END of the ledger is reported
     under the entry that opened it. A fenced line that is NOT id-keyed — recorded output such
     as `## <timestamp> -- EVENT` inside a `derived` block — is simply not a boundary and
     needs no report.
   - `RECEIPTS-UNDECIDED` → one row per run, emitted only when the count is non-zero: how many
     `theirs_has` receipts reported `STILL-LIVE` on a substring present at **base as well as
     theirs**. **The `sh` verb is counted here too, by a base control that re-runs the receipt
     with `$THEIRS` rebound to `$BASE`** — same direction at both refs means the pull moved
     neither side of it. The DETAIL carries a separate numerator per clause: `STILL-LIVE` and
     exit 0 at base, `CLOSE-CANDIDATE` and non-zero at base (the receipt had already stopped
     reproducing BEFORE the pull, so `base..theirs` is not the event to annotate a version
     with), and a REFUSED count for controls that exited 126/127 — those never ran and are in
     no numerator. Three `sh` classes get no control at all and the row names the ones with
     members: receipts naming neither `$THEIRS` nor `$DIST`, receipts naming `$BASE`
     themselves, and receipts reading `$THEIRS_TREE`. No control is taken when `$BASE` and
     `$THEIRS` are the same ref or `base..theirs` is empty; a pull that moved nothing is a
     different claim and the row makes it by staying silent.
     This pull moved neither side of those predicates, so their verdicts are
     restatements of the previous run rather than new measurements — the entry may be live or
     long fixed, and this run did not distinguish them. **A `STILL-LIVE` in that set is not
     evidence the defect survives.** An anchor on text the fix KEEPS survives the fix, and the
     entry can then never close. Measured on the reference consumer at 0.301.0: of five
     `STILL-LIVE` verdicts re-checked against the code by hand, **three were false**, every one
     anchored on text its own fix keeps, and only one of the three was visible to
     `NAMED-UPSTREAM`. It is a COUNT, not an accusation against any row — "present at both refs"
     is also the normal state of a genuinely live entry, so it cannot decide one. Re-anchor the
     receipts per the rule below, or read the code. **Do not read a zero `CLOSE-CANDIDATE` count
     from such a run as evidence that nothing was absorbed.**
   - `INPUT-UNRESOLVED` → an ARGUMENT does not resolve, so **nothing was re-verified**. Run-
     scoped rather than entry-scoped: the entry column carries the offending path. Two causes,
     named in the DETAIL — the consumer root is not a directory, or an explicitly-supplied
     arg-5 ledger path is not a readable file. This row exists because that state would otherwise be
     spelled as **zero rows and exit 0**, which is exactly how a clean corpus is spelled, and
     the argument order is the trap: this tool takes consumer THIRD and theirs FOURTH while
     every sibling in `reconcile/` takes `<dist> <base> <theirs> <consumer>`. Fix the
     invocation and re-run before reading any other verdict from that run. **Never drain on a
     run that emitted this** — a zero close count from it means nothing was examined.
   **Anchor a `theirs_lacks` receipt on a token upstream MUST use, never on predicted
   prose.** The substring for a fix that does not exist yet is a guess at wording upstream
   has not written, so it closes only if upstream happens to pick the same words. Anchor on a
   status name, a flag, a filename, a manifest row — something the fix cannot be written
   without. A receipt that only matches one phrasing of a fix is a receipt for that phrasing,
   not for the fix.

   **Anchor a `theirs_has` receipt on a token the FIX MUST REMOVE.** The rule above protects
   the verb the unfalsifiability guard already covers; this one has no guard at all, and it is
   the verb most receipts use. A token that merely CO-OCCURS with the defect survives the fix,
   so the entry reports STILL-LIVE forever against a defect that no longer exists — and it
   passes every lint, because it is well-formed, its path resolves, and it is reachable at both
   refs. Real case: an entry about `emit-report.sh --verify` being bound to one dist checkout
   anchored on the rendered `full: diff <(git -C $DIST show` line. The fix landed in the
   COMPARISON (`--verify` now normalises the path on both sides), and the rendering was kept
   deliberately, so the anchor is still there and the receipt still says STILL-LIVE. Ask of the
   substring: *could the fix be written without removing this?* If yes, it is the wrong anchor —
   anchor `theirs_lacks` on the token the fix cannot be written without.

   **Never reproduce a receipt's substring in the core file that receipt tests.** A
   `theirs_lacks` receipt is satisfied by ANY occurrence in that file, including one written
   to discuss the receipt, so quoting it closes the entry with nothing behind the close.
   Name the entry; describe what it asks for.

   **Read the distribution through `$THEIRS_TREE` or a rev-spec, never through `$DIST/…`.** An
   `sh` receipt runs with `$DIST`, `$BASE`, `$THEIRS`, `$CONSUMER` and `$THEIRS_TREE` exported,
   and only two of those are paths: `$CONSUMER` and `$THEIRS_TREE`, a materialized tree of the
   distribution at theirs (no `.git` in it, so use it as a directory). `$DIST` is the
   distribution's CHECKOUT — it goes to `git -C` and nothing else, because the working tree under
   it sits wherever the operator last left it and is under no obligation to be at theirs. A
   receipt reading it as a path measures a ref the pull is not pulling while the row claims it
   measured theirs; `ledger-reverify.sh` refuses that form as `NEEDS-REVIEW` rather than scoring
   it. Measured on the reference consumer: 2 of 28 `$DIST`-naming receipts (of 37 `sh` receipts)
   read it as a path and both produced a false `CLOSE-CANDIDATE` in one run.
   `cd "$DIST" && git show "${THEIRS}:…"` is the same correct read in another form and is
   accepted; a bare `cd "$DIST"` followed by anything else is refused. **The accepted spelling
   is exact** — `cd "$DIST" && git …` or `cd "$DIST"; git …`, one space before `git`. A
   `cd "$DIST" || exit 127; git show …`, an unquoted `cd $DIST`, a `cd -- "$DIST"`, and a
   double space or a tab before `git` are all refused as `NEEDS-REVIEW` even though they read
   theirs correctly. That is the safe direction — a refusal costs one read, an acquittal costs
   an entry — but write one of the two accepted forms, or use the `git -C "$DIST"` rev-spec,
   and the question does not arise.

   **A `$THEIRS_TREE` receipt opens with `[ -n "${THEIRS_TREE:-}" ] || exit 127;`.** Re-verify
   runs on the engine the consumer LAST INSTALLED, so until the consumer pulls the release that
   ships `$THEIRS_TREE` — and on that pull itself under `SELF-UPDATE-DEFER`, an un-synced step 2,
   or a failed step-2 push — the running engine does not export it: unguarded, the receipt reads `/…`, exits non-zero, and that
   engine scores it `CLOSE-CANDIDATE`. `exit 127` is the "subject renamed or deleted" status every
   shipped engine already turns into `NEEDS-REVIEW`, so the guard degrades the receipt to a review
   instead of a false close.

   An entry with NO `verify:` line gets no receipt verdict and is left to hand-review; only a
   `NAMED-UPSTREAM` row can reach it, and it re-appears every pull until the entry is closed by
   annotation. The convention is opt-in and the ledger stays prose. The line is one of
   `theirs_lacks <core-path> "<substr>"` (innovation upstream lacks),
   `theirs_has <core-path> "<substr>"` (defect present upstream), `sh <one-liner>`
   (exit 0 = still reproduces), or `manual`. A `theirs_*` line MAY carry more than one quoted
   substring; all must match. **The substring is literal and has no escape mechanism**: write
   backticks and quotes bare inside the double quotes. A substring carrying a backslash is
   refused as `NEEDS-REVIEW`, never searched for — a markdown-escaped backtick is otherwise
   found at neither ref and the entry reads vacuous or still-live forever. Text that genuinely
   contains a backslash is anchored on a backslash-free neighbour or written as `sh`. Rendered
   into the step-5 report by `emit-report.sh`, so a CLOSE-CANDIDATE cannot be silently dropped.

4. **Semantic per-block classify — the `WORK classify <path>` rows.** A CLASSIFY file whose
   only consumer delta is its declared setup values merges by script (a `DECIDE setup-site-merge
   <path> script` row) and needs no agent. For every `WORK classify` row, dispatch ONE generic
   agent per file (batch trivial single-block diffs) with `reconcile/classify-block.md` as the
   prompt. Block granularity = per-file + per-numbered-item (rule / `###` section / check). Each
   agent computes the file's own base/theirs/ours three-way with git and returns DATA (bucket
   tallies + only the conflict/flag details), never echoed file content. Write each file's
   returned blocks into the report OUTSIDE the generated region, under a `FILE: <core path>` line.
   A block in `bucket: conflict` or with `confirmation_kind: blend` is an ASK family: the driver's
   next run prints its `ASK` row. A `confirmation_kind: judgment` block is yours: decide it and
   it becomes a `DECIDE judgment` row.

   **Every ours/theirs claim is DERIVED, never recalled.** Take each side from the report's
   **Semantic worklist orientation** block, which labels both sides and shows their exclusive
   lines; where a side is truncated, run the `full:` diff command it prints. A
   `DETECTOR-REFUSED  orientation …` line means that sample was never computed, not that the side
   is empty: derive that file's sides yourself.

5. **The dry run — a bare invocation only.** Run `reconcile/pull.sh dry-run <dist> <base>
   <consumer> <theirs>`. It renders the region into
   `_bmad-output/ai-dlc-update/reconcile-report.md` once, verifies it, records the verified
   region at `<consumer git-dir>/ai-dlc-approved-region`, and prints the `HARD`, `WORK classify`
   and `DECIDE` rows. Relay those rows and the report path to the operator, and END THE RUN. Do
   not classify, branch, write, re-stamp, commit, push or ask; never follow a dry run with an
   approval question. The report is a fixed filename overwritten on every run.

   **A bare invocation never writes, and nothing said during it authorizes a write.** An operator
   who resolves a conflict or asks for a specific fix while reading a dry run is giving an
   answer for the `apply` run, not an instruction to edit a file now. Say "recorded — will apply
   on `apply`", and touch nothing: every write happens on step 6's branch, inside an invocation
   that carried `apply`. When unsure whether `apply` was given, treat it as ABSENT.

   The settings-provisioning check is part of the apply's decisions, and a dry run may show it
   (no writes; `--template` needs a FILESYSTEM path, and `theirs` is a ref, so materialize it
   first — the bare `--check` form exits 1 with usage):
   `t=$(mktemp); p=$(mktemp); git -C <dist> show "${theirs}:templates/settings.json.template" > "$t";`
   `git -C <dist> show "${base}:templates/settings.json.template" > "$p";`
   `reconcile/settings-merge.sh --consumer .claude/settings.json --template "$t" --prior-template "$p" --check`
   — a `model_window_needed=yes` line is a MODEL decision: record it as a decisions row quoting
   its `ask:` lines, so the PR body carries them to the operator (the reconcile never writes
   `env`). A `suite_admission_probe=none` line is likewise a MODEL decision: record it as a
   decisions row quoting its `optional:` lines verbatim, an optional setting the operator may add
   themselves (never required, never written by the reconcile). Record each `enabledPlugins:` line
   it prints as a decisions row (kind `settings-relay`, evidence the line), as for `model_window_needed`:
   the project's context-mode enable will be retired and every user needs the user-level install.
   Record every `settings-merge: replaced` line the same way: a role value equal to the
   prior template's value will be overwritten with the new template's.

6. **Isolate — branch before ANY write (apply only, MANDATORY).** The reconcile
   MUST NOT mutate the consumer's live branch in place. Before the first write
   in step 7:
   - Shell to git in the consumer tree. If it is not a git repo, STOP and tell
     the operator (no safe isolation possible).
   - If the working tree has uncommitted changes that would tangle the reconcile
     diff, STOP and report — let the operator stash/commit first. (A dirty tree
     unrelated to the rulebook may be fine; when in doubt, stop.)
   - Re-confirm the step-1 git preflight still holds: the branch is in sync with
     its upstream. **Do not push here, ever.** Time may have passed since the
     dry-run, and a push rejected because the remote advanced leaves the local
     upstream ref stale, so the unfetched counts read ahead-only when the branch is
     diverged. **Fetch first**: `git fetch <remote>` for the remote the upstream
     names, then recompute the ahead/behind counts with step 1's detect commands.
     An upstream-less branch has nothing to fetch and is refused below as
     upstream-less; a fetch that fails STOPs `apply` with the fetch error. If the
     branch is not in sync with its upstream — ahead, behind, diverged or
     upstream-less — or step 1 or step 2 left it UN-SYNCED on this invocation, **STOP
     `apply`** and report the ahead/behind counts and the remedy: the push step 1
     names for ahead-only or upstream-less, `git pull`/rebase for behind or
     diverged; then re-invoke with `apply`. This is the ONE place a failed step-1
     push refuses anything. A consumer with no remote configured has no upstream
     to match and is not refused here, exactly as step 1 lets it proceed. The
     reconcile branch cut here must sit on a base that matches `origin`.
   - `pull.sh apply` cuts `ai-dlc-update/<theirs-version>-reconcile-<ts>` off the current
     branch before its first write (a resolution round already on that branch stays on it).
     ALL step-7 writes land there, so the operator reviews a clean diff / opens a PR — never
     a silently-mutated working branch. Run the checks above BEFORE `pull.sh apply`.
   This is a hard requirement, symmetric with the pipeline's own branch-per-unit
   discipline; the `_divergence/` archive (step 9) is a backstop, not a
   substitute for the branch.
7. **Apply — reached ONLY when the invocation carried `apply`, after the step-6 checks.** Run
   ONE `reconcile/pull.sh apply [--carried-machinery-slice] <dist> <base> <consumer> <theirs>`. In order, it renders the
   region once, records the approved region, prints every `ASK` and `HARD` row and exits 3 before
   any write if there is one, cuts the step-6 branch, runs `reconcile/apply.sh` (every MECHANICAL
   resolution, reusing that render's detector outputs), then prints the `WORK classify`, `ASK
   deletion` and `DECIDE` rows and writes the decisions record. It never writes the stamp: the
   stamp still reads `<base>` after it and the in-flight marker stays. Work what it hands back,
   then run `pull.sh finish` with the same four arguments and flag, `<base>` included (the
   `NEXT pull.sh finish …` line prints that command when nothing it ran is outstanding).

   **Two refusals stop `pull.sh apply` before its first write (exit 2).** `REFUSED
   apply-pull-writes-moved`, on a retry of the same `<theirs>` off an `ai-dlc-update/*` branch,
   follows one `NOTE pull-writes-moved <path> recorded <blob> now <blob>` per file the pull wrote
   whose content changed since its last driver step: move your own edit out of each named file
   (re-apply it after the PR merges), or, for a step-7 merge, re-run `pull.sh finish` so the record
   takes it, then re-run apply. (`pull.sh record` is deliver's remedy; it refuses an apply that is not finished.) `REFUSED apply-pull-unfinished`, on a new `<theirs>`, follows one
   `NOTE pull-writes-unfinished <path> theirs <sha>` per file another pull wrote and left
   uncommitted at its written content: finish and deliver that pull with its own `<theirs>`, or
   discard its writes to those files yourself, then re-run apply. `NOTE pull-writes-unrecorded`
   (a pull begun under an engine that kept no record of its writes) refuses nothing.

   **On exit 3, nothing was written.** For each `ASK` row, ask its question (*The driver* above)
   and act on the answer. For each `HARD` row, resolve it as `reconcile/detector-rows.md` gives
   that code — a `HARD-*` row is a condition the tool cannot DECIDE, so the write waits for its
   resolution, never for a guess — and record your disposition as a decisions row with its
   evidence. Then run `pull.sh apply` again with the same four arguments: each resolution round
   costs exactly one more render. A HARD row you resolved by `--stamp readopt` or a register
   record no longer renders, and the driver's union gate accepts that on its own; an `ASK-UNANSWERED`
   refusal means a conflict reached the tree without an operator answer, so ask it.

   **Override merges go ONLY through `reconcile/pull.sh merge <dist> <base> <consumer> <theirs>
   <override>` — never call `readopt-override.sh --merge` directly.** A clean merge prints
   `DECIDE override-drift <rel> merged` and is recorded; a CONFLICT leaves markers in the body and
   prints `ASK conflict-hunk <rel> <digest> <question>` (exit 3): present that hunk, nothing else,
   and write the answer into the body. Never hand-edit a body that the merge can produce.
   An override whose shadowed section is, at `<theirs>`, a load-pointer stub (a section carrying
   the `READ AND FOLLOW rule-bodies/rule-N.md` sentence; `OVERRIDE-SHADOWS-POINTER-STUB` in
   `reconcile/detector-rows.md`) is never merged: `pull.sh merge` relays `readopt-override.sh`'s
   `REFUSED … OVERRIDE-SHADOWS-POINTER-STUB` row and its remedy verbatim, records no decision and
   exits 3, and `--stamp readopt` and `--stamp reaffirm` refuse on it while `shadows:` names the
   stub. The row's remedy, verbatim: "run readopt-override.sh <dist> <theirs> <consumer>
   <override> --stamp retire, then file this override's rows upstream as a change to the
   intensity table of the stub that owns the rule (the SKILL.md stub, per distribution
   invariants I19 and I131; rule-bodies/rule-N.md holds a copy)."

   **The rows `apply.sh` hands back, by class** (each detail field is authoritative about its
   remedy; the driver prints each `WORKLIST` and `DECISION` row as a `DECIDE <kind> <path> pending`
   row). **Add `--carried-machinery-slice` — first, before the four paths — to
   `pull.sh apply` and `pull.sh finish` if and only if step 2 deferred its self-update and handed
   this run the machinery slice**; that is what advances the
   stamp's `skill_version`/`skill_commit` beside `version`/`commit` (see the re-stamp bullet at
   the end of this step).
   - `RESOLVED …` — already done, no operator step: pure applies (core overwritten from theirs),
     new-role arrivals (a new role file states no model or effort, so there is nothing to fill: its model and effort come from its `aiDlcRoles` entry), **known-drift refiles**
     (`provenance-block.json` `known_skills` → `extensions/known-skills.json`, core reverted — the
     "migrate the drift" chore, automated), catalog relabels, **setup-sited merges**
     (`setup-site-merge`: a setup-sited file whose only consumer delta is its declared setup
     values, merged with `git merge-file` and checked against theirs outside its spans), and the
     version re-stamp, which `pull.sh finish` prints and `pull.sh apply` never does.
   - `WORKLIST …` — the only things left for YOU. Work EVERY row, whatever its kind: each one
     names concrete work in its own detail field, and the re-stamp is withheld until all of them
     are disposed. `semantic-merge` is a BOTH-CHANGED 3-way PROSE merge per `classify-block.md`,
     and `override-readopt` is worked with the loop below; the rest state their own remedy.
     **Do not read this bullet as the list of kinds.** It named two while the apply emitted
     eleven, and a reader checking whether their row "counted" against a two-member list is
     reading a restatement that stopped tracking its subject. The kinds are declared at their
     emitting sites in `reconcile/apply.sh`, which is the only place they are complete.
   - **A row whose detail begins `<i>/<n> ATOMIC` is one step of an ORDERED SEQUENCE.** Do every
     step of that subject in the printed order and commit them together. Do not reorder them, do
     not land one without the others, and do not treat the last step as the whole item. The order
     is a safety property, not a preference: an `override-retire` sequence writes the replacement
     configuration BEFORE deleting the entry, because deleting first re-imposes the core
     constraint the entry was widening onto a consumer whose artifacts already violate it, and
     the next gate then fails on a tree you just repaired. Each step states its own consequence.
   - `DECISION …` — a call the apply could not make on its own: an unknown drift's
     refile-vs-revert, a deletion, a token with no default. Decide each and record it as a
     decisions row; a row in an ASK family (`reconcile/ask-families.tsv`) reaches you as an
     `ASK` row instead, and a deletion the script could not prove safe as `ASK deletion`.
   - `DECISION <detector>-refused` (`unregistered-drift`, `retired-tokens`,
     `retired-layer-passage`, `layer-drift`) — that detector refused, or could not write all of
     its rows, so its section is **NOT a finding of "none"**. The detail carries its exit and its
     own `REFUSED` line. Run the named script directly against this consumer, clear the cause
     that line names, and re-run the apply. Never dispose of it as "no drift".
   - `DECISION staging-refused` — the apply could not write one of its own staging files (a full
     or read-only `TMPDIR`, or a file-size limit), so the section that file feeds is **UNKNOWN,
     not clean**, and no row it would have produced was emitted. The detail names the section and
     the remedy that clears it. Under `--finish` the same row is a `WORKLIST` and withholds.
   - `NOTE …` — never withholds the stamp, and is not counted with the handed-back rows. Read
     every `NOTE` row of an `apply.sh` run BEFORE you work that run's `WORKLIST` rows: a `NOTE`
     can cancel or subsume a `WORKLIST` row on the same path (`override-readopt-subsumed` against
     `override-readopt`; `extension-retire` or `extension-contradicts-core` against
     `extension-title-match`). Where a `NOTE`'s detail prescribes an act, do it in this pull as
     owed work, even though the stamp did not wait for it. Relay EVERY `NOTE` row of every
     `apply.sh` run of this pull, re-runs and `--finish` included, to the operator in the PR body
     (step 8): give each kind once, with its row count and paths, and quote the full detail only
     for a row whose detail, or this step, prescribes an act, saying whether that act was done.
     `derivation-unassessable` is one such row: this step has you adjudicate each one by hand and
     relay each one in full. **Do not read this bullet as the list of kinds.** The kinds are
     declared at their emitting `say NOTE` sites in `reconcile/apply.sh`, except that the
     `<kind>` of a `derivation-info-<kind>` row is field 2 of the `INFO` row
     `derivation-differential.sh` printed.

   **A printed remedy that names the raw engine is run through the driver.** A row or refusal
   that tells you to run `apply.sh --finish`, `apply.sh --carried-machinery-slice` or
   `readopt-override.sh --merge` is run as `pull.sh finish`, `pull.sh apply` or `pull.sh merge`,
   with the same arguments and flag. Both paths refuse to stamp over an unanswered ask; the
   driver is the documented path because it also prints the `ASK` rows and flushes the
   decisions record. Only the driver rewrites the record of the pull's own writes that deliver
   compares; after a raw engine run, deliver refuses `deliver-pull-writes-moved`.

   **`apply.sh` runs the derivation differential and records what it finds; you do not run it for
   the record.** A derivation this pull broke is RECORDED OWED in
   `_bmad-output/ai-dlc-update/owed-derivations.tsv` and drawn as a `WORKLIST artifact-derivations`
   row; a refused measurement is a `DECISION artifact-derivations-differential` row. `apply.sh`
   mints the reconcile log's name once per pull and prints it as a `NOTE reconcile-log-name` row;
   write your log at exactly that path. Each `NOTE derivation-unassessable` row is a derivation the
   validator refused on either side: adjudicate it by hand, record it as a decisions row, and relay
   it IN FULL in the PR body. To close an owed row, append `REPOINTED<TAB><old file:line><TAB><new
   file:line><TAB>$ <new command>` to the record; the reader re-derives it on every read. The
   record's full contract is `reconcile/detector-rows.md`'s.

   Do NOT re-do a `RESOLVED` row by hand. Work the `WORKLIST` and `DECISION` rows, and every
   `NOTE` row as the NOTE bullet above says. **The adjudication loop for `HARD-*` and
   `override-readopt` rows** — build the evidence with `reconcile/readopt-override.sh <dist>
   <theirs> <consumer> <override>`, decide retire / readopt / reaffirm in one sentence, do it,
   stamp it, re-run the two drift detectors on their own bases — is in `reconcile/detector-rows.md`,
   with the per-bucket actions (`UPSTREAM-DELETED`, `ORPHANED-RELOCATED`, setup-token substitution,
   `TEMPLATE-PROSE-MERGE`) and the flagged-block checkpoint. You do the surgery; the decision is
   recorded, not asked, unless its family is in `reconcile/ask-families.tsv`.

   `WORKLIST pre-gate-repair <path>:<line> <header>` rows (or one `SKIP pre-gate-repair <reason>`
   line) follow the apply: each names an escalation entry with no Status line. List them in the PR
   body, which the script already does; they never block and never withhold the stamp.

   - `TEMPLATE-JSON-MERGE` (from the template pre-classification) → run
     `t=$(mktemp); p=$(mktemp); git -C <dist> show "${theirs}:templates/settings.json.template" > "$t"; git -C <dist> show "${base}:templates/settings.json.template" > "$p"`
     then `reconcile/settings-merge.sh --consumer .claude/settings.json --template
     "$t" --prior-template "$p"`. `--template` is read with `-r` and
     `theirs` is a git ref, so a ref-qualified template path fails the read guard.
     **Do not hand-write the jq** — the script is the contract. It strips stale
     `ai-dlc-*.sh` hook blocks + appends the template's, and preserves user
     permissions/env/mcpServers/statusLine. It writes nothing into `env`: the
     `AI_DLC_MODEL_<FAMILY>_WINDOW` declarations the `model_window_needed` decisions row names
     are the operator's to add, and an existing value is never touched.
     `enabledPlugins` is additive-only with one retirement: the script removes the
     project's `context-mode@context-mode` entry when its value is exactly `true`
     (context-mode is a user-level install, so every user of the project needs
     `claude plugin install context-mode@context-mode --scope user`), never a
     `false` and never any other plugin; the rest of the consumer's
     `enabledPlugins` is preserved in full. `--check` prints one `enabledPlugins:`
     line when the retirement will fire; it runs only when the template wires
     hooks, so uninstall never retires.
     `apply.sh` hands this back too, as a `WORKLIST template-json-merge` row that withholds
     the re-stamp, after running `settings-merge.sh` on a copy of the file: a copy that
     changes means the merge is owed, a copy that does not means it is done and no row is
     printed. The same test runs on every pull, whether or not the range changed the
     template, so any fill the merge owes reaches the file; the row then quotes the
     `enabledPlugins:`, `settings-merge: filled` and `settings-merge: replaced` lines the merge prints, and
     each `enabledPlugins:` and `settings-merge: replaced` line is recorded as a decisions row (kind
     `settings-relay`, evidence the line). A file that is
     owed is recorded on a `template:` line, and `--finish` re-checks it by running
     `settings-merge.sh` on a copy again, which must change nothing, or it prints
     `WORKLIST finish-template-json-unmerged` and withholds. The deliberate-no-op exit is
     deleting that file's own `template:` line; while the copy still changes, the next
     pull asks again. A fill is declined for good in the file itself: a role key by
     declaring it in the consumer's role (a key held at the prior template's value is
     replaced by the new template's, so decline that by giving it any other value, or
     by deleting the file's `template:` line, which clears it for good because the next
     pull's prior is the new value), a plugin by setting it `false`,
     `bashOutputMaxChars` by declaring a number. These have no such opt-out, because
     the merge always restores them: an edited or reordered ai-dlc hook block, a
     template role or `aiDlcModels` key the consumer deleted, and the file's event-key
     order and formatting. A file `settings-merge.sh` refuses (not a JSON object, a key
     of the wrong type) raises no row, and no fill reaches it until it is fixed; a
     refusal the engine causes still prints `DECISION template-json-refused`.

   **RUN THE POST-WRITE GATES THROUGH ONE SCRIPT, AND READ ITS VERDICT LINES — NEVER A GATE'S
   PROSE.** The five gates below (leftover tokens, setup-site drift, hook registration, taught
   schema, and the `hard-blockers.sh --post-apply` re-run) are exit-code gates. After the last write, run them
   together, unpiped:

   ```
   reconcile/post-write-gates.sh <dist> <base> <consumer> <theirs>
   ```

   It runs each gate with its output redirected to a file and its exit code captured on the next
   statement, and prints one line per gate — `GATE <name> PASS|FAIL|UNDECIDED rc=<n> … out=<file>`
   — then one `POST-WRITE-GATES PASS|FAIL|UNDECIDED …` summary. Exit 0 only when every gate
   passed AND the summary says `overridden=0`. `--stub` is the fixture's hook: a run with any
   override exits 1 even when every verdict reads PASS, and its summary says
   `overrides-in-force`. Never pass `--stub` on a pull. On a non-zero exit, open the `out=` file the failing line names; that is the gate's
   whole output. The `hard-blockers` line carries `hard=<n>`: those are the HARD rows still
   standing, and each must be one the operator accepted per path before apply.

   **A gate whose exit code was not observed is UNDECIDED, and UNDECIDED is never a pass.** Each
   gate's rows, its fallback form (when `reconcile/post-write-gates.sh` is absent) and its remedy
   are in `reconcile/detector-rows.md`.

   **THE STAMP IS WITHHELD WHILE ANY ROW IS OUTSTANDING, AND `pull.sh finish` IS HOW YOU ADVANCE
   IT. THIS IS A REQUIRED STEP ON EVERY PULL, NOT A RECOVERY PATH.** `pull.sh apply` runs
   `apply.sh --stamp-at-finish`, which never stamps: it leaves the stamp at `<base>` and
   `.claude/.ai-dlc-applying` in place, so the consumer's fixture suite refuses on purpose and
   `pull.sh deliver` refuses `deliver-pull-unfinished`. A run that hands back any `WORKLIST` or
   `DECISION` row prints `DECISION restamp-withheld`; a run with nothing outstanding prints no
   restamp row, and the driver prints `NEXT pull.sh finish …`. When every row is disposed, run
   `reconcile/pull.sh finish [--carried-machinery-slice] <dist> <base> <consumer> <theirs>` with
   the `<base>` the apply was given. It runs `apply.sh --finish`, which first checks the CONFLICT
   GUARD (an `ASK` row means a conflict or blend reached the tree without an answer: exit 3),
   then checks the tree and does the stamp and the marker clear; it writes no core file. A `DECIDE
   <kind> <path> withheld` row (exit 3) is a check `--finish` failed: dispose of it and run `finish`
   again. A `DECIDE <kind> <path> advisory` row (hook registration, transient ignore, agent
   definitions, taught schema) is printed after the stamp and never holds it or the marker: do its
   work before deliver. When the `restamp-withheld` row says a fresh ordinary run is the remedy instead, run
   `pull.sh apply` again with the same arguments; `finish` is not the next step there. Every row
   `--finish` can emit is listed in `reconcile/detector-rows.md`.

   - Re-stamp the rulebook base: set `version`/`commit` = `<theirs-version>` /
     `<theirs-sha>`, **preserving `skill_version`/`skill_commit`/`installed_at`/
     `upstream`** (rewrite the whole stamp in schema — never collapse it to the
     legacy single line, which would drop the skill version and upstream URL).
     **`apply.sh` does this; you do not edit the stamp.**

     **THE ONE EXCEPTION, AND IT IS A FLAG RATHER THAN A JUDGEMENT CALL.** If step 2
     reported `SELF-UPDATE-DEFER`/`SELF-UPDATE-UNDECIDED` and handed its machinery
     slice to this apply, then this run DID install machinery, and the skill pair
     must advance with the rulebook pair — pass `--carried-machinery-slice` to
     `pull.sh apply` and `pull.sh finish`, which pass it to `apply.sh`, and the finish writes
     all four.
     Withholding still applies to BOTH pairs or neither. A stale `skill_commit` makes every
     machinery file this apply wrote read as consumer drift on the next pull.

     **`pull.sh finish` stamps whenever its checks pass — INCLUDING an empty reconcile** (zero
     rulebook blocks applied, e.g. a self-update-only pull): the `apply` run then hands back
     nothing and prints `NEXT pull.sh finish …`, the finish is a stamp-only bump checked against
     that `<base>`, and the log records "already current, stamp advanced <base> → <theirs>."

     **When the apply that wrote this tree already stamped** (an apply run by an engine that
     predates the deferral, which happens on the pull that delivers it under
     `SELF-UPDATE-DEFER` or `SELF-UPDATE-UNDECIDED` when that apply handed back nothing), the
     stamp reads `<theirs>` and the marker is gone, so the finish withholds once with
     `finish-base-unverified`. Re-run `pull.sh finish` with the stamp's own `commit:` as `<base>`,
     as that row says: it exits 0 and verifies nothing that the earlier apply did not, so record
     it in the reconcile log as an unchecked finish.

   - **YOU write `_bmad-output/ai-dlc-update/reconcile-log-<ts>.md`, and `apply.sh` does NOT.** When the apply drew a `NOTE reconcile-log-name` row, `<ts>` is the stamp in that row's path: write the log at exactly that path, because the owed-derivations record's field 7 names it.
     Write it LAST, after the post-apply re-runs, because it records them. It carries the gates
     before the first write, the apply manifest, the stamp transition, the post-apply re-runs on
     their own bases, the validator outcomes, the ledger decisions, and what was deliberately not
     done.

### Mask/reinject transform (setup-substitution sites)

Lives in `reconcile/mask-reinject.md`. Read it when `apply` hands back a `semantic-merge` row for a file `reconcile/setup-sites.md` lists: read it in consecutive bounded native Read chunks (offset+limit) of at most 16 KB, never `ctx_*`, and re-read it on need after a compaction.

**Probe the installed BMAD before Deliver (step 7z).** `reconcile/pull.sh deliver` runs
`scripts/ai-dlc/validate-bmad-invocations.sh` itself when the consumer's
`_bmad/_config/manifest.yaml` differs from the digest recorded at the last validated pull
(`_bmad-output/ai-dlc-update/bmad-manifest-digest`). Exit 1 refuses with
`deliver-bmad-invocations` and nothing is committed or pushed: read the `FAIL:` lines on
stderr, take the remedy `npx bmad-method install` (or revert the BMAD change), commit the
resulting `_bmad/` rewrites with the pull, and re-run deliver. No recorded digest: the FAIL
lines and remedy print to stderr as a report, never a block. Any exit other than 0 or 1
(DISARMED, usage, validator missing): a SKIP NOTE, never a block, and no record is written.

When `deliver` prints `NOTE bmad-probe unchanged`, still run
`scripts/ai-dlc/validate-bmad-invocations.sh` from the consumer root: the rulebook just applied
may invoke a skill the unchanged install lacks. Report exit 1 `FAIL:` lines as delivery findings
(the floor, remedy `npx bmad-method install`) and exit 2 as SKIP; this run never blocks.

   **Deliver through the driver.** Step 8's commit, push and PR are one
   `reconcile/pull.sh deliver <dist> <base> <consumer> <theirs>`, run after `finish` exits 0 and
   after the ledger work step 8 gives you. It runs on the `ai-dlc-update/*` branch only, commits
   only the pull's own writes (step 8's Commit bullet), pushes so the consumer's pre-push runs, and
   opens the PR against the branch the reflog says this one was cut from, with a script-rendered
   body, bounded in bytes and checked before the push: the decisions record, the reconcile region
   and, where it differs, the dry-run region. Its refusals all come before any write.
   `REFUSED deliver-pull-writes-moved` follows one `NOTE pull-writes-moved <path> recorded <blob>
   now <blob>` per file the pull wrote whose content changed after its last driver step (`pull.sh
   apply`, `finish` or `merge`): your own edit since then, or a step-7 merge made after the last
   driver run. Move your own edit out of each named file (re-apply it after the PR merges), or,
   for a merge, run `pull.sh record <dist> <base> <consumer> <theirs> -- <path>...` naming each
   such file so the record takes it; then re-run deliver. `record` rewrites that record and nothing
   else, and prints `NOTE pull-writes-recorded <n> <theirs>`; deliver discloses each re-recorded
   path as `NOTE pull-writes-rerecorded <path>` in the commit message and the PR body. It refuses
   `REFUSED record-path-unnamed rc=2` (one `NOTE pull-writes-moved` per path first) while a recorded
   path whose content moved is not named after `--`, `REFUSED record-pull-unfinished
   rc=2` while the in-flight marker `.ai-dlc-applying` exists and `REFUSED record-no-record rc=2`
   when no record names this `<theirs>`. A delivered pull writes
   `<git-dir>/ai-dlc-pull/pull-writes.delivered`, and the next `<theirs>`'s unfinished check skips a
   record whose `<theirs>` it names.
   `REFUSED deliver-dirty-overlap` follows one `NOTE deliver-dirty-overlap <path> overlap|unrecorded`
   per file that was already dirty when the pull began, that the pull also changed, and whose
   change cannot be separated from your edit (`overlap`: the edits touch the same lines;
   `unrecorded`: its pre-pull content was not recorded). Staging the file does not lift the refusal.
   Only the operator decides to commit such a file whole: re-run deliver with `--whole <path>` per
   file, which commits the worktree file, their edit included, and writes `NOTE deliver-dirty-whole
   <path>` into the commit message and the PR body. To keep the edit out, save it aside and take it
   out of the file first, re-run with `--whole <path>`, then restore it. A `DECIDE <status> <block> drain` row
   is a push-drain row for step 8's drain. `DECIDE push-red <log>` (exit 3) is yours: diagnose the
   red push from that log, fix the cause on this branch, record the diagnosis as a decisions row,
   and run `deliver` again. A fix that edits a file the pull wrote makes that run refuse
   `deliver-pull-writes-moved`; take that refusal's `pull.sh record -- <path>` remedy for the fix, then run `deliver`
   again. `ASK base-confirm` (exit 3) is step 8's no-reflog-line case. The driver
   NEVER merges: on `DECIDE pr <url> opened`, the merge and the RETURN PROCEDURE are yours, exactly
   as step 8 states them.

8. **Deliver — branch → commit → push → PR → merge.** The reconcile is landed
   through the consumer's normal review flow, never force-written to the working
   branch:
   - **Drain `push_candidate` extensions through the reader, never by hand.** Run
     `reconcile/push-drain.sh <dist> <theirs> <consumer>`. It splits every extension whose
     frontmatter says `push_candidate: true` into blocks and emits one row per block,
     `PUSH-REFUSED` or `PUSH-CANDIDATE`, keyed on the block's digest against
     `reconcile/push-refusals.tsv` at `theirs`. Drain ONLY the `PUSH-CANDIDATE` rows into the
     push-candidate ledger for a later upstream push-mine (spec §8.1). A `PUSH-REFUSED` row is a
     block upstream already adjudicated and declined; re-proposing it re-opens a settled verdict.
     A block whose body has changed since it was refused digests differently and comes back as a
     `PUSH-CANDIDATE`, which is correct: it is a new proposal. **On any non-zero exit the reader
     REFUSED** — its own refusals exit 2, and a closed stdout under the default SIGPIPE
     disposition exits 141 with no line: report its `push-drain: REFUSED —` line where there is
     one and drain NOTHING from this run, because a partial or unread record re-proposes refused
     blocks exactly as the prose drain did.
   - **Drain the defects this run found in UPSTREAM's own tooling** into the same ledger,
     one entry each, with a `verify:` line. Every other drain here moves a CONSUMER
     artifact; this is the other source, and it had no path. A pull is the best detector
     of these defects — it is the only context that runs `reconcile/*` end-to-end against
     real divergence — and what it finds otherwise lands in `reconcile-report.md` under a
     follow-ups heading that nothing re-reads and the next run overwrites (step 5: "a
     fixed filename overwritten on every run, a snapshot, not a log"). A refusal, a status
     with no actor, a remedy that cannot be executed, a check that passed vacuously: file
     it. Filing it is not the same as fixing it, and this step never fixes upstream. A defect first
     found at Push, Open a PR or Merge (the delivery push runs the consumer's pre-push) is
     drained the same way and committed onto the same branch before the PR is merged.
   - **Every filed defect CITES the command that found it.** One literal command and its
     decisive output line — the discipline `steps/discovery.md` already imposes on the
     prior-decision search, where a zero-hit pass is valid ONLY if the command is shown. A
     claim about WHY a detector emitted a row is an INFERENCE, not a finding: label it as one,
     or verify it and cite that. The mechanical region is rendered and `--verify`'d precisely
     so detector output cannot be narrated; the prose AROUND it had no such rule, and that is
     where the wrong headline finding of each of the last two pulls came from — one filed
     against a checker that was correctly obeying an over-wide declaration, one calling a
     token inside a historical anecdote a second live vocabulary. Both were grep hits rendered
     as conclusions without reading the surrounding line. A third was a CORRECTION derived
     from the three refs already loaded rather than from the history, and it was wrong too.
   - **Re-run the re-verifier over what you just wrote, before the drain is done.**
     `reconcile/ledger-reverify.sh <dist> <base> <consumer> <theirs>` again, and read the rows
     for the entries this step added. Any of them landing `NEEDS-REVIEW` — unresolved, vacuous,
     or unfalsifiable — is a receipt to FIX NOW, not to file. Step 3f lints receipts on READ,
     so an entry authored here is first checked one pull later, after a pull has already acted
     on it. Last cycle this step wrote malformed receipts into the same document that correctly
     explained that defect class. The whole ledger re-verifies in ~1.5s; this costs nothing.
     It scans TRACKED files only, so first stage the files step 7 created by explicit pathspec
     (`git add <path>`, never `git add -A` or `git add .`); the Commit bullet below commits them.
   - **Close any `CLOSE-CANDIDATE` entries from step 3f.** For each, confirm the upstream
     version at `theirs` covers your entry (the row's detail names the sha and the version),
     then annotate the ledger entry `**ADOPTED UPSTREAM (v<theirs>, verified <date>)**`, matching
     the existing hand-written closure format. **The bold span is what the rotator reads** — a
     close written without one is skipped-but-unarchivable. A close inside a long entry TITLE may
     wrap across a line break with the span still open; that is read as one annotation.
     Two other close forms are honoured
     and neither takes a version: `**WITHDRAWN (<date>) — <why>**` for an entry whose premise was
     false, and `**CLOSED AS REJECTED — BY DESIGN, adjudicated <date>**` for a candidate upstream
     considered and declined. Never invent a version to make a close archivable. When the
     row's detail says the receipt ALREADY did not reproduce at base, `v<theirs>` is the wrong
     version: annotate with the release that detail routes you to, never `v<theirs>`.
     **Do NOT delete the entry** — retro and the
     §8.1 fan-in read it. The annotation is an `Edit` under `_bmad-output/ai-dlc-update/**`
     (the updater's own directory, carved out of the Rule 29 acknowledge hook), never a
     Bash write, and never automatic. Close ONLY `CLOSE-CANDIDATE` rows, or an entry the
     push-drain bullet below finds all-refused; a `NEEDS-REVIEW` row is never a close, whatever
     its detail says.
   - **An entry whose every live block reads `PUSH-REFUSED`** in this run's
     `push-drain.sh` output can never close on its receipt, because upstream will never ship
     what it declined. Annotate it by hand with `**CLOSED AS REJECTED — BY DESIGN, adjudicated
     <date>**`, the same manual `Edit` and never automatic, as the close bullet above requires.
     Do this only when every block of the entry's extension is refused; one `PUSH-CANDIDATE`
     block leaves the entry open.
   - **Every other status in the push-candidate heading has a disposition here, and none of
     them is a close.** `reconcile/emit-report.sh` renders the set the operator acts on and
     this is the step that acts, so a status named there and not here is a duty with no actor.
     Step 3f says what each status MEANS; these say what to DO with it.
     - `NAMED-UPSTREAM` — upstream's history names the id. Read the named commit and decide
       whether it ABSORBED the entry or recorded a rejection or a split. On absorption,
       annotate by hand in the form `ledger-rotate.sh` accepts — bolded, version immediately
       after the parenthesis — the same edit the bullet above describes; otherwise re-anchor or
       drop the stale receipt. Naming is not absorption and the row is never an auto-close.
       **The row supplies no version and you must establish one**: find the release that
       CONTAINS the absorbing commit, which is not the same as the `VERSION` file at that commit
       — a fix that lands before its bump reads one release early there. The row deliberately
       stopped guessing it, because a version read off a commit that merely NAMES the id is a
       claim about the wrong event and the annotation it lands in is permanent.
     - `NAMED-UPSTREAM-AMBIGUOUS` — the commits cite the bare sprint prefix, however many open
       entries carry it (one included). Deliberately NOT attributed: read the named commit and
       decide per entry. Annotate nothing on the strength of the row alone.
     - `NAMED-UPSTREAM-DOCS-ONLY` — upstream's history names the id but no naming commit
       changes `core/` or `templates/` or cuts a release. Read the commits for a withdrawal or a
       split and act on that if there is one. Then read the entry's own subject against
       `theirs`: the naming is not evidence of an absorption, but a fix landed under a commit
       that does not name the id still closes it. Annotate only what that reading establishes,
       with the release that contains the change; otherwise leave the entry open.
     - `NAMED-UPSTREAM-OFF-SUBJECT` — the naming commits change installed paths but none
       changes the receipt path(s) the row names, a release judged over its span. Read the
       commits: the id may have been dispositioned by an earlier release and this naming be a
       later mention. Then read the named subject against `theirs`. Annotate only what that
       reading establishes, with the release that contains the change; otherwise leave the
       entry open.
     - `NAMED-UPSTREAM-SIBLING-ATTRIBUTED` — a naming commit changed the receipt file only where
       a sibling entry it names has its anchor. Read the commits and the sibling's entry: the
       change may be the sibling's fix with this entry merely cross-referenced. Then read this
       entry's subject against `theirs`. Annotate only what that reading establishes, with the
       release that contains the change; otherwise leave the entry open.
     - `NAMED-UPSTREAM-CITED-ONLY` — every naming commit cites the id only on a
       `Not-discharged:` line, so upstream says it did not discharge the entry there. Read the
       commits for a rejection, a withdrawal or a split and act on that if there is one, then
       read the entry's subject at `theirs`. Annotate only what that reading establishes;
       otherwise leave the entry open.
     - `HAND-REVIEW` — the entry declares `verify: manual` and no mechanical predicate exists
       for it by design. Adjudicate the body against `theirs`; annotate only what that
       adjudication establishes.
     - `NEEDS-REVIEW`, `INPUT-UNRESOLVED`, `RECEIPTS-UNDECIDED`, `ENTRY-SWALLOWED` — the
       RECEIPT or the entry's own shape is the defect, not the entry. Repair it here, the way
       the re-run bullet above requires, and close nothing on one.
   - **Rotate the closed entries out.** `reconcile/ledger-rotate.sh <ledger>` reports what
     would move; `--apply` moves it to `push-candidate-ledger.archive.md`. The ledger is
     append-only otherwise, so it grows every sprint and never shrinks — measured at 2830
     lines / 220 KB / 50 entries on the reference consumer, of which only 39 still
     classified. Every pull parses the closed ones, every report renders them, and every
     receipt edit pays for their bytes. Rotation moves, never deletes, and requires the
     annotation form — a **bold span** carrying the close marker — rather than the phrase
     anywhere: an entry wrongly kept costs one pull to notice, one wrongly archived costs the
     work. That grammar is `ledger-reverify.sh`'s own close rule with its optional bold span made
     mandatory, derived at run time by `reconcile/lib.sh`'s `ledger_archive_awk()`, so every token
     the re-verification honours as a close is archivable and the two cannot drift apart.
     **Acceptance test:** `ledger-reverify.sh` must emit the same ROW SET before and after
     the `--apply` — by status and subject, `cut -f1,2 | sort` either side. Rotation moves
     exactly the entries it already skips, and `ledger-reverify.sh` never reads the archive —
     every number it prints is counted over the OPEN entries of the live ledger — so a rotation
     that swept nothing changes no row and no detail. **Compare the
     row set, never a row COUNT** — a count is a property of the ledger's size on the day, and
     a swept entry can hide behind a duplicate. If a row appears, disappears, or changes status
     — including `NAMED-UPSTREAM <slug>` becoming `NAMED-UPSTREAM-AMBIGUOUS <prefix>` or the
     reverse — that is the signal; STOP, and read the entries that moved before anything else.
     No difference is benign here: the sprint-prefix count inside
     `NAMED-UPSTREAM-AMBIGUOUS` details never dips while an entry sits annotated-but-unrotated,
     because a bare prefix is never attributed to an entry and the count reads no history.
     A flip of the surviving sibling's row between the two statuses above on a two-member
     prefix therefore cannot occur, and one that appears reads exactly like a sweep.
   - **Commit** the pull's own writes and nothing else, on the step-6 reconcile branch: the
     step-7 writes and the step-8 ledger writes above (the ledger and
     `push-candidate-ledger.archive.md`, `operator-answers-history.md`), the paths that were clean when
     the first apply ran except the pipeline's own state files
     (`.claude/schemas/pipeline-state-paths.json`) that no record of this pull names, and, for a file
     already dirty then that the pull also changed, only the pull's change to it; the
     pull's artifacts (the report, the reconcile log, the decisions file, the gate and push
     records), the paths this pull's own records name, and any path staged explicitly. The
     operator's pre-existing dirty, untracked and staged state stays out of the commit and is left
     untouched, staged or not. A dirty file whose edit overlaps the pull's change, or whose
     pre-pull content was not recorded, is committed whole only on the operator's `--whole <path>`,
     disclosed in the PR: otherwise deliver refuses `deliver-dirty-overlap` before any write (step 7's deliver paragraph names the remedy). Never `git add -A` or `git add .`, and never `git commit -- <paths>`.
     The PR body is bounded in bytes and checked before the push. The commit has a subject
     like `chore(ai-dlc-update): reconcile distribution <base-ver> → <theirs-ver>`
     and a body summarizing buckets applied + conflicts adjudicated + the log path + every
     `NOTE` row of this pull's apply runs, as step 7's `NOTE` bullet says.
   - **Push** the reconcile branch to the consumer's remote (`origin`). If there
     is no remote or push fails (a local-only consumer), STOP here and hand the
     operator the local branch + diff to merge manually — do not silently drop
     the work.
   - **Open a PR** into the working branch (`gh pr create`), body = the reconcile
     report summary (buckets, conflicts, push-candidates) and every `NOTE` row of this
     pull's apply runs, as step 7's `NOTE` bullet says.
   - **The PR's base is named, never defaulted:** `gh pr create --base <cut-from>`, where
     `<cut-from>` is the branch this one was cut from, derived from HEAD's reflog exactly as
     step 1's skill-branch bullet states, never remembered. Untangle mode derives it the same
     way, because its step 6 is also a `git checkout -b`. Before any merge, refuse to create the
     PR when `<cut-from>` matches step 1's skill-branch grammar, and report that this branch
     was cut from another skill branch whose work has not reached the working branch. When
     no reflog line matches (the reflog expired or is disabled), the prior behaviour applies:
     state the base in the PR presentation for the operator to confirm; nothing refuses on
     that account.
   - **Merge ONLY on explicit operator approval of the PR.** This is a second,
     independent gate — separate from the `apply` arg that authorized the write.
     The skill does NOT auto-merge. None of the following authorize a merge: zero
     conflicts, a clean diff, the `apply` arg already given, or inferred intent.
     Present the PR and wait for the operator to approve it.
     If you hold the advisor tool, call it in a message of its own before `gh pr merge`.
     Only then merge
     (squash, delete branch). On merge, the re-stamp + log + changes reach the
     working branch.
     The literal merge command is the next bullet.
   - **The merge command is literal:**
     `gh pr merge <n> --squash --delete-branch=false --match-head-commit <sha>`, where `<sha>` is
     `git rev-parse <reconcile-branch>` taken
     when the operator approves, so the merge takes exactly the commit that was approved
     and the RETURN PROCEDURE's tip gate below holds by construction. It passes
     `--delete-branch=false`, so gh moves no checkout and asks nothing; the RETURN PROCEDURE
     below makes the move and deletes the branch.
   - **RETURN PROCEDURE — after every merge, return the checkout to the working branch.**
     Defined here once; step 1's skill-branch bullet, step 2's return bullet and untangle
     mode cite it. Every clause reads state before it acts, so a run after the merge tool
     already switched and pulled is a no-op that reports "already on <working> at
     origin/<working>". (a) Run
     `gh pr view <n> --json state,baseRefName,headRefName,headRefOid`. `<working>` is its
     `baseRefName` and `<skill-branch>` is its `headRefName`, never remembered values, and a
     compacted or resumed session derives them the same way. STOP, naming the state and the
     base, when the state is not `MERGED` or when `<working>` matches step 1's skill-branch
     grammar. (b) Run
     `git fetch origin "+refs/heads/<working>:refs/remotes/origin/<working>"`; a failed fetch
     STOPs with its error (the ABANDON form below treats it as a note instead). (c) After that fetch and before any checkout, run **the
     working-tree check**, a named, self-contained block that another procedure may cite and
     run as written. Its one input is `<working>`, the branch the checkout is about to move
     onto; its output contract is that ANY output line is a STOP, and an empty output
     means the move may proceed. Its changed set is the UNION of the paths the checkout of local `<working>`
     writes and the paths the fast-forward to `origin/<working>` writes (`--no-renames`
     keeps both halves of a rename); a ref that does not exist is skipped, so nothing goes
     to stderr. It prints `DIRTY <path>` for a changed path that is tracked and dirty,
     staged or not, and `ON-DISK <path>` for one absent from HEAD yet present on disk, which
     covers untracked AND ignored files:
     ```
     ( cd "$(git rev-parse --show-toplevel)" || { echo "STOP cannot cd to the repository toplevel"; exit; }
       { git rev-parse -q --verify "refs/heads/<working>" >/dev/null && git diff -z --name-only --no-renames HEAD <working>
         git rev-parse -q --verify "refs/remotes/origin/<working>" >/dev/null && git diff -z --name-only --no-renames HEAD origin/<working>; } |
       sort -zu |
       while IFS= read -r -d '' p; do
         if ! git diff --quiet HEAD -- ":(literal)$p"; then echo "DIRTY $p"
         elif ! git cat-file -e "HEAD:$p" 2>/dev/null && { [ -e "$p" ] || [ -L "$p" ]; }; then echo "ON-DISK $p"
         fi
       done )
     ```
     A STOP from the working-tree check names each printed path; the procedure itself never
     stashes or forces. The remedy depends on the tag. `ON-DISK <path>`: move the file
     aside, then re-run the block. `DIRTY <path>`: copy the file elsewhere, then run
     `git restore --staged --worktree -- <path>`, then re-run the block. Never commit on the
     skill branch to clear a path, because a new commit breaks (f)'s tip gate. When the
     re-run prints nothing, go on to (d). The block runs in a subshell from the repository
     toplevel, because the paths git prints are toplevel-relative. Paths travel
     NUL-delimited, so a name carrying a quote, a backslash, a tab or a newline reaches the
     tests unquoted, and `:(literal)` stops pathspec magic in a file name. An empty union
     prints nothing and the procedure goes on. Never cut paths out of
     `git status --porcelain` columns. Git refuses atomically per command, not across the
     checkout and the fast-forward together, and it overwrites an ignored file without
     refusing, so this block guards the pair and the ignored case. (d) When the
     current branch is not `<working>`, run
     `git checkout <working>`: never `-f`, never a stash, never
     `git switch --discard-changes`. On a refusal, STOP with git's error verbatim and the
     `git status --porcelain` output; the skill branch stays checked out and nothing is
     lost. (e) Run `git merge --ff-only origin/<working>`. On a refusal, STOP with git's
     error verbatim and the counts from
     `git rev-list --left-right --count origin/<working>...<working>` (behind first, then
     ahead), and add step 1's diverged remedy only when ahead is above 0. (f) When the local
     skill branch still exists, delete it with `git branch -D <skill-branch>` ONLY when
     `git rev-parse <skill-branch>` equals the PR's `headRefOid`; otherwise STOP naming it,
     because it holds commits the merge did not take. When the local branch is already
     gone, print `REMOTE-KEPT <skill-branch>: no local branch to gate on` and delete nothing
     remote. After the local delete gate passes, delete the REMOTE skill branch only when
     its tip is still the merged head, with this one block, `<headRefOid>` being the PR's:
     ```
     ( e="$(mktemp)" && o="$(mktemp)" || { echo "REMOTE-KEPT <skill-branch>: mktemp failed"; exit; }
       if ! gh api "repos/{owner}/{repo}/git/ref/heads/<skill-branch>" --jq .object.sha >"$o" 2>"$e"; then
         grep -qF '(HTTP 404)' "$e" || echo "REMOTE-KEPT <skill-branch>: remote tip unreadable: $(tail -1 "$e")"
       elif [ "$(cat "$o")" != "<headRefOid>" ]; then echo "REMOTE-KEPT <skill-branch>: remote tip moved"
       elif ! gh api -X DELETE "repos/{owner}/{repo}/git/refs/heads/<skill-branch>" >/dev/null 2>"$e"; then
         grep -qF 'Reference does not exist' "$e" || echo "REMOTE-DELETE-FAILED <skill-branch>: $(tail -1 "$e")"
       fi )
     ```
     The lookup's own exit and its stderr file are read FIRST, never a pipeline's status:
     a failed lookup ending `gh: Not Found (HTTP 404)` means the ref is already gone and
     prints nothing, and any other failed lookup prints `REMOTE-KEPT … remote tip unreadable`;
     neither runs the DELETE. Only a successful lookup compares the sha, and only a match
     runs the DELETE. A DELETE failing with `gh: Reference does not exist (HTTP 422)` means
     the ref is already deleted and prints nothing; any other, such as
     `gh: Bad credentials (HTTP 401)`, prints the `REMOTE-DELETE-FAILED` line. It is not a git push, so no pre-push hook runs. A
     `REMOTE-KEPT` or `REMOTE-DELETE-FAILED` line is never silent and never a STOP, because
     the local return has already succeeded.
     **The remote delete runs ONLY in (f) of this post-merge procedure, after (a) has
     confirmed the PR is `MERGED` and after the local-delete tip gate above has passed: never
     before (a), never in the ABANDON form, and never when the local branch was already gone,
     because then no tip gate passed.** The merge
     can happen after this session ends, in the UI or by the operator, so this bullet is not
     the only carrier of the return: step 1's skill-branch bullet runs the same procedure on
     the next invocation.
     **Its ABANDON form** moves the checkout off an UNMERGED skill branch: (b) when a remote
     exists, then (c), (d) and (e), with `<working>` set to the branch it was cut from, as
     step 1's reflog derivation gives it, or the branch step 1 confirmed in sync on this
     invocation when no reflog line matches. It skips (a) and never runs (f), because the
     skill branch is unmerged and stays. With no remote, (b) and (e) are skipped. When (b)'s
     fetch fails, ABANDON reports the fetch error as a note, skips (b) and (e), and goes on
     with (c) and (d) against local `<working>`; a failed fetch is never an ABANDON STOP.
     Every remedy in this skill that moves the checkout from a skill branch onto a working
     branch names this procedure or its ABANDON form, never a bare `git checkout`.
9. **Safety.** Three independent recover layers: the step-6 reconcile **branch**
   (the working branch is never touched), the consumer's
   `docs/pre-ai-dlc/<ts>/_divergence/` archive (written by install), and the
   dry-run report. Nothing the pull cannot prove it wrote is destroyed without an operator
   confirm.

   Both literal `gh pr merge` commands pass `--delete-branch=false`, so gh's merge moves no
   checkout, and the RETURN PROCEDURE in step 8 is the only move onto a working branch.
   gh runs its local branch switch and pull only when its delete-branch value is true, and
   `--delete-branch=false` fixes that value without a prompt, including the prompt gh
   offers on a terminal for a PR that is already merged.
   The procedure's gated
   `git branch -D` deletes only a tip the merge took, one equal to the merged PR's
   `headRefOid`, which is why it needs no operator confirm; the branch is restored
   with `git branch <skill-branch> <headRefOid>`.

## Layered consumers (Rule 27 / spec §7) — the reconcile shrinks

When the consumer has the Phase 2 layer split (a populated
`{skill}/extensions/` and/or `{skill}/overrides/`), the reconcile surface
collapses:

- **core** (the protected-manifest files) → overwrite from theirs wholesale,
  running the **mask/reinject transform** (`reconcile/mask-reinject.md`) first for any file listed in
  `reconcile/setup-sites.md`. No per-block classify needed for rulebook prose
  — the consumer never edited core in place there (the gate-validation
  Core-layer immutability check guarantees it) — but base→ours is NOT empty
  at declared setup-substitution sites (model strings, ownership paths,
  deploy/smoke commands); those always differ from base by design, forever.
  The three-way degenerates to a fast-forward everywhere EXCEPT those sites,
  which mask/reinject handles without needing a classify pass.
- **extensions/** → never **written** by the pull (consumer-owned), but no longer
  invisible to it. Step 3c's `layer-drift.sh` reports `EXTENSION-HOOK-DRIFT` when
  the hooked core file changed, and `EXTENSION-RETIRE-CANDIDATE` when upstream has
  absorbed a section the extension defines (Rule 27(b) — the consumer retires it;
  the pull never deletes a layer entry). Entries flagged `push_candidate: true`
  are drained at step 8 through `reconcile/push-drain.sh`, block by block, and
  only its `PUSH-CANDIDATE` rows enter the push-candidate ledger (spec §8.1).
- **overrides/** → the ONLY genuine three-way surface. For each override, its
  base is the core rule it shadows (`base_sha` in the entry). If theirs changed
  that core rule between `base_sha` and HEAD, the override is re-adopted through
  `pull.sh merge` (override-drift, spec §10): a clean merge is a recorded decision, a
  conflict hunk is asked, and a shadowed section that is a load-pointer stub at theirs
  (`OVERRIDE-SHADOWS-POINTER-STUB`) is refused, never merged. **This is computed by step 3c's
  `layer-drift.sh`, not by hand** — it was prose here for its whole existence and
  consequently never ran. An override whose `base_sha` does not resolve in the
  distribution is a HARD finding that blocks `apply` (Rule 27(a)); it is never
  treated as "unchanged."

On a pre-Phase-2 (tangled) consumer like graph's first pull, none of the above
applies yet — run the full per-block classify. The Phase-2 untangle (`reconcile/untangle.md`) is what
moves a consumer from the full reconcile to this cheap one.

## Untangle mode — one-time Phase-2 migration (`untangle` = dry-run, `untangle apply` = execute)

Lives in `reconcile/untangle.md`. Read it only when the invocation carries `untangle`: read it in consecutive bounded native Read chunks (offset+limit) of at most 16 KB, never `ctx_*`, and re-read it on need after a compaction.

## Shared engine, thin orchestrator

The per-block classifier (`reconcile/classify-block.md`) is a SHARED engine
that serves four jobs (design §8): pull-reconcile (this skill), push-mine,
Phase-2 untangle, and N→1 fan-in dedupe. `ai-dlc-update` is only the **pull
entry point** that calls it — it does not own it. Keep the classifier prompt
free of pull-only assumptions so the other three jobs can reuse it.
