# Pipeline efficiency analysis: the repeatable runbook

**Resume: READ and FOLLOW docs/plans/pipeline-efficiency-analysis.md**

Run this when the operator asks for the pipeline efficiency analysis again. Its worked example is
`docs/analysis/pipeline-efficiency-s323-opportunities-b261.md` and its directory
`docs/analysis/pipeline-efficiency-s323-opportunities-b261/` (`steps/`, `findings/`, `scripts/`, `README.md`).
The extraction and roll scripts are `docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py` and
`roll.py`. This block replaces any older copy of these instructions; the figures and the sprint range in the
first reader's brief are the only state that changes between runs.

## Start here

- Repos: `/Users/n8/git/ai-dlc` is written, in a worktree outside the main checkout, on one branch from
  `origin/main`. `/Users/n8/git/graph` is the consumer: read it, never write it, and dispatch no pull
  (`.claude/rules/operator-rulings.md`, "A consumer pull is NOT preapproved").
- Corpus: `~/.claude/projects/-Users-n8-git-graph/`, read only.
- Clock: hours are in-session time on the monotone clock (BL-1174). Idle time between a handoff and the next
  resume is excluded; state that exclusion once, in the method section.
- Dollars are API-list-equivalent at `roll.py` prices, stated at both cache-write rates (one-hour and
  five-minute); never claim which is billed.
- The engine's step files are `core/skills/ai-dlc/steps/*.md`; the check that the form of this runbook is
  valid is `scripts/validate-plan-shape.sh:39`.

## Current state

The s323 analysis is landed at the path above. The next run covers the sprints after s323 and writes a new
report named `docs/analysis/pipeline-efficiency-<last sprint>-opportunities-b<batch>.md`, with its directory.

## Next actions

0. DESIGNATE THE LEAD. The session that accepts the one-liner is the lead. It runs `ListAgents`, surveys every
   other `ai-dlc-*` session for its state, and assigns each available one a cluster as one release after
   scoping. The lead never builds: owners build through hands, and an owner makes no edits itself (every edit
   goes to a hand). Every hand's brief carries this sentence verbatim: "Time matters here: do not spend time
   that can be avoided, and the earlier a correct result is obtained, the better." Every hand runs on this
   machine as a background `Agent`; a writing hand passes `isolation: "worktree"`, a read-only hand passes
   none. A hand's brief forbids `rm -rf` on a variable path and never says to leave worktrees in place; the
   lead removes every worktree it spawned before reporting closed. Train rules, by label: RELEASES BEFORE
   MEASUREMENTS, SHORTEST GATE FIRST, NO IDLE SESSIONS, NO TIMING RUNS, RELEASE TEXT IS PREPARED IN ADVANCE,
   BUNDLE ONLY TO CUT WALL CLOCK. The lead alone allocates VERSIONs and backlog ids.

1. Fix the population. Take the sprint range from the operator. List the graph engine versions each sprint
   ran: read the `ai-dlc-update reconcile <old>-><new>` commits in `/Users/n8/git/graph` over the window
   (`git log --grep` there, read only) and the version stamps in
   `_bmad-output/implementation-artifacts/s<N>/gate-adjudication/*.verdict.json`. Write the version list and
   the pin `EXTRACT_WIN_END=<utc timestamp>` at the top of the report's method section.

2. Fix the scope. The step list is the union of (a) every file under `core/skills/ai-dlc/steps/` at each
   engine version from action 1 (`git ls-tree` per version tag of this repo, never a glob against the
   manifest, which declares `steps/*.md` as one wildcard), (b) the current tree's
   `core/skills/ai-dlc/steps/`, (c) `core/skills/ai-dlc-update/` (the update skill), and (d) the consumer's
   extensions and overrides for each step: `/Users/n8/git/graph/.claude/skills/ai-dlc/steps/`,
   `/Users/n8/git/graph/.claude/skills/ai-dlc/extensions/` (`checks/`, `roles/`, `steps-domain/`) and
   `/Users/n8/git/graph/.claude/skills/ai-dlc/overrides/`. State the engine version beside each step. The
   report carries one section per step in the list; the analysis covers the entire pipeline.

3. Rebuild the extraction. From the repo root, with the pin from action 1:
   `export EXTRACT_WIN_END=<pin>; B=docs/analysis/pipeline-efficiency-s317-s320/scripts;
   A=docs/analysis/pipeline-efficiency-s317-s318/scripts; python3 -I $B/extract.py $OUT && python3 -I
   $A/spawns.py $OUT && python3 -I $A/analyze.py $OUT && python3 -I $B/roll.py $OUT > $OUT/roll.txt`, where
   `$OUT` is a fresh `mktemp -d` under the scratchpad. Control: `cmp $OUT/roll.txt` against the committed
   `docs/analysis/pipeline-efficiency-s323-complete-b261/out/roll.monotone-clock.txt` for the sprints that file
   covers must report no difference; a differing `cmp` against `roll.default-clock.txt` must also report a
   difference. Do not proceed on a failed control.

4. Dispatch one reader per step from action 2, in parallel, each as a read-only background `Agent`. Each
   brief carries the time sentence of action 0 and the preamble of the previous run (`steps/` README of the
   report directory names it). Each reader answers, for its step, over the analyzed sprints (the last sprint in
   most detail, the others so one sprint's accident is not read as the step's nature):
   A. What the step is told to do: read the step file end to end in chunks, list its parts in order (every
      sub-step, round, agent dispatch, script, gate, commit, push and operator touchpoint) each with file:line
      and one line of purpose; state the file's bytes, lines and code blocks and how much is procedure a
      script could carry versus judgment; read the consumer's extensions and overrides for the step as part of
      its text.
   B. What each part cost, per sprint: wall-clock minutes, lead-active minutes and calls, agent spawns,
      agent-minutes and dollars, operator wait, critical path or beside another part; name the parts that
      could not be separated and why.
   C. What each part produced: the files, records, findings, commits or decisions, with paths in the consumer.
   D. Who reads what it produced: grep the engine and the consumer for readers of each path, check later
      transcripts for a Read of it, check whether its findings were repaired, cited or carried on. An output
      nothing reads is a finding; a reader that only checks existence is a finding.
   E. What each part caught: findings by severity, how many changed a shipped artifact, how many another part
      also caught, and the named failure case with a real instance; read the earlier `docs/analysis/step-value-*`
      files first and check whether the new sprints agree.
   F. A verdict per part: KEEP (with the catch that earns it), SHRINK, MERGE, SCRIPT, MOVE or CUT, with hours
      and dollars freed per sprint (upper bound where it is one), what could be lost, and the engine file:line
      that would change.
   G. The step as a whole: the smallest version that keeps every earned catch, and the redesign if larger
      than a tweak.
   H. What was not measured and whether it was available.
   Readers keep scripts and small result tables in one named directory,
   `docs/analysis/<report>/steps/<step>/`, created under the scratchpad first and copied at action 11, with a
   10-line README naming each script and its output. Readers return findings as text, tiered BLOCKER /
   DEFECT / NOTE, in parts of at most 9,000 characters (a hook denies a subagent writing a report file).

5. Dispatch the cross-cutting readers beside the step readers, each read-only: lead time (decode-bound
   latency, compactions, post-compaction recovery), tokens and subagent dollars (fixed context per spawn),
   operator asks (classify every ask: needed and unforeseeable, same decision answered before, took the
   marked recommendation, no recommendation, not a decision), tool runtime, the test-suite admission wall
   (count distinct refusals as a floor, per-seat and per-hour, and the critical path with and without the
   waits), and the advisor calls (every post-compaction call read and classified CAUGHT, ADJUSTED,
   CONFIRMED or IGNORED).

6. Recover findings verbatim. Each reader's text is copied from its transcript into
   `docs/analysis/<report>/findings/<reader>.md` by the lead, never retyped. Check a payload cut at about
   16,000 characters by asking the reader for the tail. Scan every findings file for the operator's email
   address, credentials, tokens, private keys and long verbatim operator messages before committing; keep a
   line or two of quoted operator evidence, trim the rest to a one-line paraphrase marked [trimmed], and list
   the trimmed passages in the report to the operator.

7. Run the reconcile pass BEFORE any figure is published. One reader (`steps/reconcile/`) (a) reruns the
   uncorrected aggregation and requires it to match the committed `steps.csv` rows and `cmp`-identical
   `roll.txt` of action 3, (b) then applies the instrument corrections one at a time and prints the old and
   the corrected per-step table with the class split (lead model, lead tool, idle with no agent running,
   waiting on agents under 300 s, operator, long agent wait), spawns, subagent dollars at both cache-write
   rates, lead calls and compactions: step attribution from the lead's declared transitions
   (`snapshot-update.sh --set current_step_file`, gate open and close records, `gate-checkpoint.sh --nonce`
   spans), operator wait over the whole span of every ask plus the pause flag to the next human prompt,
   forked sessions counted once, idle tails after a session's last tool call removed, and sprint edges
   re-derived rather than hand-kept. Until BL-1174 lands the extractor taking those boundaries from the
   pipeline's own declarations, apply the corrections by hand from `steps/reconcile/` and name each one in
   the report's instrument section. Control: every corrected row's classes sum to its elapsed hours, and spawns
   and lead calls are unchanged by relabelling.

7a. Take step and gate boundaries from the pipeline's own records. (a) Every redesign that replaces a file the
   lead reads (a gate run as a program, a split step file, a scripted late step) still writes the snapshot's
   `current_step_file` sets and the gate open and close records. (b) The extractor takes step and gate
   boundaries from those records and sprint boundaries from the consumer's sprint-close commits; that change
   exists before the next sprint's reading is taken. (c) Every item lands before the next graph sprint, so
   that sprint measures the items together: the per-step tables attribute an effect to a step, not to one
   change inside it. No pull is dispatched by this action.

8. Answer every question the record can answer before it reaches the operator. Each value reading (does a
   round, panel, pass or call earn its place) ends in a verdict supported by named catches and read to the
   point of the verdict; an item open "pending a reading" is a defect of the run. A reading that overturns an
   earlier reader's proposal is stated in the decisions section with the evidence.

9. Decide on the standing rule. Removing, merging or reshaping a pipeline step, round or sub-step is decided
   from evidence under `.claude/rules/operator-rulings.md`, "A step with no measured value goes", and
   reported, not asked. Dropping a FILED backlog item, or narrowing a goal, is put to the operator as a choice
   with a marked recommendation, one question at a time, each with a plain-language explanation, the decision
   criteria, pros and cons, and the ground truth read first. Record each answer with its date.

10. Write the report whole, never appended, at the new path, following the structure of
    `docs/analysis/pipeline-efficiency-s323-opportunities-b261.md`: first lines pointing at this runbook;
    the answer in plain numbered statements; population, method, controls, clock and scope; sprint totals and
    corrected per-step tables; whether each earlier optimization worked; the pipeline step by step in the
    order a sprint runs, each with cost, a part table (part with file:line, purpose, cost, output and its
    reader, what it caught, verdict), named catches, defects, redesigned shape, upper-bound saving with its
    overlap note, and what was not measured; what cuts across steps; ranked levers on wall clock with their
    sequencing constraints; decisions; instrument defects; corrections to earlier published figures; what was
    not established and whether it was available; how to reproduce. Every saving is marked upper bound unless
    measured; figures are quoted from the reconcile tables.

11. Commit as one records-only commit on `origin/main`: the report, its directory (`steps/`, `findings/`,
    `scripts/`, README listing every script, the reader that produced it and how to run it), and the backlog
    entries the run files (one entry per goal). Run `bash -n` on each edited script,
    `bash scripts/validate-plan-shape.sh`, the backlog validators as `.githooks/pre-push` runs them, and
    `bash scripts/pregate-self-check.sh` on the exact tree; every figure in the report equals the reconcile
    tables and a grep for any superseded count returns zero beside a control that returns non-zero. Ping the
    operator on any question, on any decision, and on completion including an early stop.

12. Update this runbook in the same commit when a step file was added, renamed or removed since the last run:
    re-derive action 2's list from the steps directory and the engine versions, re-derive the Current state
    section, and re-run every command in this file after the merge so none prints a figure the file no longer
    states.

13. Run the fresh-resume check after the docs merge: merge the docs commit, then read this runbook from a
    fresh checkout of `origin/main` as a stranger resuming it, re-run the commands of actions 1 to 3 there,
    assert the Current state names no report path that a commit on `origin/main` has not landed, and run
    `bash scripts/validate-plan-shape.sh` in that checkout as the floor.

14. Hand the plan on and stop. Run `ListAgents`; if a local `ai-dlc-*` session is found (never a `graph-*`
    session), `SendMessage` it exactly `READ and FOLLOW docs/plans/pipeline-efficiency-analysis.md` and
    nothing else. A spent session answers `REFUSED: ...`, and only that reply advances to the next untried
    qualifying session from the same listing, idle ones first; an unspent receiver answers
    `ACCEPTED <path>` before acting. Once a session accepts, the sender has no further work and sends nothing
    further to it; if none is found there is nothing further to do. A session that accepts CONTINUES the run
    from the recorded state and does not restart it: it reads the decisions record and the readers' findings
    already on disk, resumes at the first action above not yet marked done, and re-runs no reader whose
    findings exist.
