---
name: sprint-review
description: Sprint-level adversarial review + party mode on complete sprint output
nextStepFile: ./deploy-validate.md
---
<!-- STEP_LOADED_TOKEN: sprint-review -->

# Sprint Review (Phase 4)

**Purpose:** Final sprint-level review across all stories before
deployment. Adversarial review + party mode on the complete sprint.

## EXECUTION SEQUENCE

FIRST ACTION, before anything else in this step: run
`bash scripts/ai-dlc/snapshot-update.sh --set current_step_file sprint-review.md 'Pipeline Position'`.
It overwrites the existing `current_step_file` bullet in
`_bmad-output/pipeline-snapshot.md` rather than adding a second live one; leave
`last_gate_passed` and `last_completed_step_file` as they stand.

Execute all sub-skills back-to-back without pausing for human input
between them. An operator decision this step raises, scope excepted, is filed as
an open `OPERATOR_DECISION` entry (`**Status:** OPERATOR_DECISION`) in `docs/escalations/pending.md` for
`deploy-validate.md` §5's `### Decisions for You` and the step continues; this
step issues no `AskUserQuestion` except for a scope decision:

### Sprint-Overall PR Incremental Pre-Staging

Sprint-overall PR MUST be assembled incrementally throughout the sprint:
carry-over candidates and partial-close accounting are drafted in
`_bmad-output/implementation-artifacts/s<N>/*.md` as anchors close,
not post-hoc at sprint-close. Final sprint-overall PR assembly = merge +
diff check only, not composition.

This rule applies UNIVERSALLY to all sprint-overall PRs, not gated on
anchor count or story count. Universality is the value — gating on
story count would reintroduce the "surprise sprint-overall content"
mode this rule prevents.

### 0. Local-tree freshness precondition

Before any sprint code is read for review, the reviewer MUST assert the
local checkout is not behind the integration branch. Run:

```bash
git fetch origin main
git rev-list --count HEAD..origin/main   # MUST be 0
```

A non-zero count means the local tree is STALE — it is missing commits
already merged to `origin/main` (e.g. a squash-merged sprint PR), so the
review (and any deploy built from this tree) would read code that does
NOT match the release-bound branch. STOP: fast-forward or rebase onto
`origin/main`, then restart the review on the fresh tree.

**Minimum mechanism (Rule 26(c)).** Failure caught: a review/deploy that
reads a local tree missing commits already merged upstream (stale-tree
drift-clobber). False-positive cost: effectively none — count 0 is the
steady state; cost is one `git fetch` per review. Removal condition:
retire only if read-time freshness becomes structurally guaranteed
(reviews always run on a freshly-checked-out `origin/main`-current tree).

Then re-run `scripts/ai-dlc/sprint-integration-check.sh` with the same arguments `implementation.md` §7 gives it, including `--onto <sprint branch>` and
`--suite-summary _bmad-output/implementation-artifacts/s<N>/integration-suite-summary.txt` (commit the refreshed summary). A
`RESULT FAIL` goes to dev teammates, and Step 1 starts only on a `RESULT PASS` tree.

### 1. Sprint-Level Adversarial Review

**Join every spawn on its DELIVERABLE** — one
`scripts/ai-dlc/wait-for-deliverable.sh --complete <path> [<path> ...]` call per wave of
seat, shard and cross files, and the same call without `--complete` for any other spawn's
deliverable, `run_in_background: true` (`_gate-procedures.md`, "Bounded-join beat"). A hand-rolled
`until`/`while`/`sleep` wait is a Rule 29 Check A violation; gate Check 25 counts it.


`/bmad-review lenses=adversarial` — final adversarial pass on the
complete sprint output. The lens runs inline in the dispatched adversary's own context, with
no per-lens subagent, and the review's plan is auto-approved, never an operator question.
**ONE-SHOT — the bmad skill is correct here and stays** (no loop, no verdict, no
counted exit condition; Check 24 skips this gate). The native `adversary` review
is for CONVERGENCE cycles only. Review:
- Walk through every change across all stories
- Check for cross-cutting issues (inconsistent patterns, missing
  integration points, duplicated logic across stories)
- Re-read the sprint's verbatim operator request — the one the snapshot's
  Sprint Context quotes and that Check 33 reads from
  `_bmad-output/operator-requests-history.md` — against the COMPOSED diff of
  every story, not against each story's own ACs; a clause two
  individually-correct stories fail jointly is visible only here
- Apply all fixes autonomously. **Code changes are applied by dev teammates and
  planning-artifact repairs by a dispatched `remediator` (`_gate-procedures.md`,
  "Adversarial repair dispatch"), not inline by the lead (Rule 28); the lead owns
  disposition, not the edit.**

**Run sub-step snapshot update after each adversarial pass.**
**Then run auto-handoff evaluation** (see `_gate-procedures.md`
\"Auto-handoff evaluation\") at `Seam D` with the label
`sprint-review adversarial pass <N>`. If evaluation returns FIRE,
the session ends; otherwise continue.

One adversary pass runs per composed tree. A repair of its findings is verified by re-running
`scripts/ai-dlc/sprint-integration-check.sh`, whose verdict replaces a second adversary pass, and by Step 3's re-review; a further adversary pass runs
only when a fix batch added story code to the sprint tree.

### 2. Sprint-Level Party Mode

**Intensity gate for lightweight.** When `validation_intensity ==
lightweight`, skip this sprint-level party mode — the single Step 1
adversarial pass satisfies the lightweight minimum. Proceed to Step 3
(Fix and Re-Validate) with any Step 1 findings.

`lightweight` is the only intensity this gate exempts. At `carry-over-single`,
and at every other intensity, this sprint-level party mode is REQUIRED — it is
not skipped, and gate-validation Check 20 resolves the sprint-review minimum by
reading this gate.

PM, Architect, Dev, TEA and QA walk through the
entire sprint implementation. The round is sharded per `_gate-procedures.md`, "Validation
cycle" item 1 (Rule 28, "Split dispatch": seats x parts axis), so it is that item's per-seat
role-bound `Agent` spawns, never the `/bmad-party-mode` Skill. That means one role-bound agent per
(seat, story ordinal) from `merge-adversarial-shards.sh --map` over the sprint's stories, plus
one cross-story agent per seat that reads every story, every seat writing early, closing with
one final `seat-complete: ... sha=<hex> findings=<n>` line appended by `wait-for-deliverable.sh --mark`, and its join beat passing `--complete`. The lead's join counts the per-seat files against that map before
dispositioning, and it counts only the files that item names. That item's seats x sections axis
is for a single-document subject, not this one.
The round goes out in waves bounded by the waves sentence of `_gate-procedures.md`, "Validation cycle" item 1, and Rule 28's Waves paragraph, never as one unbounded fan-out.
- Does the implementation match the requirements?
- Are there cross-cutting concerns?
- Is the test coverage adequate across the sprint as a whole?
- Record every finding; the seats edit nothing (that item's write model). **Code changes are
  applied in Step 3 by dev teammates, not by a seat and not inline by the lead (Rule 28); the
  lead owns disposition, not the edit.**

**Minimum mechanism (Rule 26(c)).** Failure caught: a defect only the whole sprint shows, such
as a capital path left without its halt after a burn or a funds destination reachable through a
path no single story owned, and per-story defects the one-shot pass in Step 1 does not raise.
False-positive cost: one agent per (seat, story) plus one cross agent per seat. Removal
condition: measured sprints in which this round carries no unique MAJOR or CRITICAL catch that
reaches the merged code.

**Seat dispatch.** After each wave's join beat, run `scripts/ai-dlc/sprint-review-seats.sh <seat-dir> <each expected seat file>`.
It prints `REDISPATCH <seat>` for every expected seat whose file does not end in a `seat-complete:` line,
a seat whose spawn errored (rate limit, capacity, API failure) included, and exits 1 while any remain. The
lead re-dispatches each `REDISPATCH` seat with the same brief and deliverable path and runs the script
again; the join is that script's exit 0, and an errored spawn is never counted as joined. A seat that
appended its `seat-complete:` line before its spawn errored is `JOINED` and is not redone. Exit 2 is a
refusal (seat dir missing, no seat listed), never a join.

### 3. Fix and Re-Validate

If the sprint review surfaced findings that required code changes:
- Dev teammates apply fixes
- Code reviewer re-reviews affected files
- QA re-validates affected stories
- Repeat until clean

Dispatch QA re-validation on the tip the code reviewer approved, after that approval, never in
parallel with a tree that can still change.

**Core-path seam non-deferral.** When any reviewer flags an untested
integration seam (a wiring point where one component's output must reach
another for the feature to function), the disposition MUST classify the
seam as either **wiring-reachable pre-merge** — whether the real
entrypoint actually invokes the seam is a pure-software fact knowable
in-process before merge — or **environmental** — the seam is reachable
only in the deployed environment. A wiring-reachable seam on the
sprint's PRIMARY deliverable path (the path that realizes the sprint's
headline deliverable) MUST NOT be deferred to deploy-validate;
deferring it is a HARD_BLOCK (Rule 12 Tier 1). Such a seam requires an
in-pipeline mutation-RED wiring test before merge — a test that drives
the real entrypoint and FAILS if the seam is unwired (external legs MAY
be mocked; the wiring itself MUST be exercised). Only a genuinely
environmental seam MAY defer, and the lead files each deferred seam as an
OPEN carry-over item in
`_bmad-output/planning-artifacts/carry-over-backlog.md` (ID grammar and
`**Status:** OPEN` floor owned by `carry-over-evaluation.md`) naming the
seam and the live observation that discharges it, before this step's gate.
Any override MUST name the risk verbatim:
"this could merge with every gate green and ship functionally inert."
Catches: a feature that passes code review, QA, and smoke yet ships
functionally inert because its core wiring seam was never exercised and
was deferred to a live-only check. False-positive cost: one in-pipeline
wiring test per core-path seam, external legs mocked. Remove when: the
sprint's primary deliverable path contains no cross-component wiring
seam reachable in-process before merge.

**Un-exercised decision branch.** Mutation coverage of a branch SELECTION
is not evidence that the SELECTED branch executes correctly live. When a
decision feature ships with a branch that no live or validation event has
taken, the lead files a passive live-validation carry-over item for that
branch here, in `_bmad-output/planning-artifacts/carry-over-backlog.md`
under `carry-over-evaluation.md`'s ID grammar: read-only observation, no
synthetic trigger, reopened by the first organic event that takes the
branch.

### 4. Gate Validation and Proceed

Before Seam B, run
`scripts/ai-dlc/validate-handoff-evidence.sh --strategy HEAD <every story file of this sprint>`
on the sprint branch. A fix in Step 3 that renamed a test node leaves the
`## Strategy Test IDs` cells naming the old node, and Check 21 fails them at
the gate. On exit 1, re-bind every cell its `REFUSED` lines name (fill an
empty `Kind` or `Resolves to`; point a `test` row at the node as it now
exists), commit, and re-run until it exits 0. Exit 2 is recorded verbatim in
the gate log.

Run auto-handoff evaluation at `Seam B` with the label
`sprint-review end-of-step pre-gate` (see `_gate-procedures.md`
\"Auto-handoff evaluation\"). If evaluation returns CONTINUE, run
`bash scripts/ai-dlc/gate-run.sh arms --gate sprint-review --sprint <N> --step sprint-review.md --transcript <this session's transcript_path> --transcript-dir <the directory that transcript sits in>`
(add `--series <path-prefix of the sprint adversarial pass series>` for Check 24), dispatch the adjudicator it names
(`gate-validation.md`), then run `bash scripts/ai-dlc/gate-run.sh close --gate sprint-review --nonce <gate_nonce> --sprint <N> --step sprint-review.md --transcript <this session's transcript_path>`. Check 20 loads at this
gate and reads the minimum from Steps 1 and 2 above, so the gate log entry records
`validation_intensity:` and `minimum_met:` here as it does at every planning gate.
Then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/deploy-validate.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`)
