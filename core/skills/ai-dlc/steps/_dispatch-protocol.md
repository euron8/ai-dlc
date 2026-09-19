---
name: _dispatch-protocol
description: The teammate-dispatch protocol invoked by reference from implementation.md step 2 — worktree-explicit dispatch, the bounded-join mandate, prompt-cache discipline, and the per-dispatch pre-flight checks — extracted so its body stays out of the per-story read path and loads only at the dispatch seam
---
<!-- STEP_LOADED_TOKEN: dispatch-protocol -->

# Dispatch Protocol (invoked by reference)

This file is the full text of the dispatch protocol that `implementation.md`
step 2 "Create Agent Team" invokes — it is NOT a pipeline step and has no
`nextStepFile`. A step file loads it `READ AND FOLLOW`-style when it says
"run the dispatch protocol" before spawning teammates. `implementation.md`
carries a one-line forwarding pointer at this text's former location.

It ships with the skill and is audited as pipeline-step prose under the same
standard as the step file that points at it.

**Worktree-explicit dev dispatch.** The Agent tool's
`isolation: worktree` parameter is NOT a reliable isolation mechanism
when combined with `subagent_type: general-purpose` — multiple parallel
devs collapse into shared CWD and branch-thrash each other. Lead MUST
follow the worktree-explicit dispatch protocol:

0. Lead MUST commit all planning artifacts the dev needs (story
   files, analysis docs, sprint-status.yaml) to the sprint branch
   BEFORE pre-creating any dev worktree. The worktree base MUST
   contain the canonical story file by construction; a worktree cut
   from a HEAD that predates the artifact commit strands the dev
   without its story spec and forces teardown + recreate. Violation:
   dispatch rework; surface at retro.
1. Lead pre-creates a physical worktree per dispatched story BEFORE
   issuing the Agent call:
   `git worktree add <repo>-s<N>-story-<X> -b dev/sprint-<N>/story-<X> <sprint-branch-HEAD>`
2. Dev branches MUST branch off the current sprint-branch HEAD at
   dispatch time. The lead MUST NOT branch dev worktrees off `main`
   unless the sprint branch has not diverged from main.
3. The Agent call MUST set `mode: "bypassPermissions"` and include
   the worktree absolute path in the prompt. The dev prompt MUST
   instruct the dev to `cd` into the worktree as its first action.
   The worktree path is the ONLY absolute path the prompt may carry
   (see 7).
4. On story completion, the lead merges the dev branch into the
   sprint branch and removes the worktree:
   `git merge dev/sprint-<N>/story-<X> && git worktree remove <path>`
5. If merge conflicts arise, the lead resolves them — not the dev.
6. Every dispatch brief into a worktree (dev, code reviewer, or QA)
   MUST include this standing line: "Never run `git stash` or `git
   stash pop` inside this worktree. All worktrees under one repository
   share a single stash stack, so a stash or pop here can surface or
   consume an UNRELATED stash from another worktree. For a before/after
   base compare, use `git worktree add --detach <base>` instead." Keep
   it in the dispatch template, not per-sprint prose the lead must
   remember to re-add. Failure caught: a cross-worktree stash collision
   that silently mutates another dev's working tree. False-positive
   cost: none — an isolated alternative (`--detach`) is provided.
   Removal condition: only if worktrees under one repository stop
   sharing a single stash stack (a git invariant today).
7. A worktree-isolated teammate's deliverable path is ALWAYS relative
   to its OWN worktree root, never to the primary tree. The lead MUST
   NOT ask it to write outside that worktree, and MUST NOT name a
   primary-tree path for a file the teammate is to produce. Naming two
   roots for one file in one sentence — "write to `<worktree>/…/x.md`,
   resolved relative to the primary tree" — is satisfiable in neither
   reading, and the teammate correctly writes inside its own worktree.
   The lead reads the file from the primary tree AFTER merging the dev
   branch (step 4), and translates the path itself if it needs one.
   Two consequences, and both have to be stated because the second is
   where the cost landed:
   - **Do not arm a `wait-for-deliverable.sh` beat on a primary-tree
     path for a worktree dispatch.** That path cannot exist until the
     merge, and the merge is downstream of the join, so the beat can
     never be satisfied. Join on the WORKTREE path, or join on nothing
     and read the file after step 4.
   - **A beat reporting non-delivery is not evidence the teammate is
     working.** Before re-arming the same beat a second time, check
     teammate liveness directly; an idle teammate with an absent
     deliverable is a diverged path, not a slow one.
   Failure caught: a dev completed its fix in ~7 minutes and went idle
   while the lead's beat watched a primary-tree path, re-armed twice,
   and the real state took three separate reads to reconstruct. The
   equivalent warning already existed in `team-roles/adversary.md`,
   which is the ONE role told never to run worktree-isolated — so it
   sat where it could not fire. False-positive cost: none, the lead
   loses no capability it had. Removal condition: only if a
   worktree-isolated agent's absolute paths begin resolving against
   the primary tree.

**Bounded-join dispatch mandate (Rule 29).** A gated story-dev cycle is
synchronous: the lead's immediate next action reads the dev's result
and routes it into gate-1. That JOIN is mandatory and unchanged. What
is forbidden is waiting for it in a single blocking Agent call, which can
run for tens of minutes. While that call is in flight there is no tool
boundary, so a queued operator message cannot be delivered: the human is
locked out for the duration.

The lead MUST therefore dispatch teammates with `run_in_background: true`
and JOIN on the **deliverable file**, not a `task_id` — conducting that
join by arming a **backgrounded** wait-beat and ENDING THE TURN.

A dev, code-reviewer, and qa are all `Agent` spawns. **`TaskOutput`
cannot join an `Agent` spawn** (Rule 29, "Which join, and this is not a
preference") — it takes a `task_id`, which only `TaskCreate` produces.
Every ai-dlc teammate delivers by file (Rule 20), so the file IS the
handle. Wait on it with Rule 29's **bounded file-wait beat**, run in the
background — do not retype the loop:

    Bash(run_in_background: true):
      scripts/ai-dlc/wait-for-deliverable.sh <path> [<path>...]

Then END YOUR TURN. The beat sleeps off the foreground; when it exits the
harness re-invokes you with its result. Branch on the exit code THEN:

    exit 0 — BEAT COMPLETE. Read the output, do not infer from the code:
             `DELIVERED <path>` — consume it, route into gate-1.
             `WAITING <path>`  — re-arm the beat (Bash,
             `run_in_background: true`) over the still-pending paths and
             yield again. Do NOT foreground-poll, do NOT narrate-then-stop.
             A beat that is still waiting exits 0; that is not a failure.
    exit 1 — NON-DELIVERY. Re-dispatch ONCE (--reset), then HARD_BLOCK.

**The one hard invariant: never end your turn on an outstanding join
without a live backgrounded beat armed.** The armed beat IS your own
re-invocation; a yield without one is a dead pipeline. While a beat is
live the Stop hook (`ai-dlc-continue.sh` Check 2b) allows the turn to
end — a yielded lead is reachable *immediately*, better than mid-beat,
not worse.

**A wave dispatched in one message is joined in ONE beat.** Pass every
teammate's deliverable to a single invocation — they poll inside the
same beat. Never chain beats (`wait a.md; wait b.md`) into one `Bash`
call: two beats is two budgets and the call overruns.

The script bounds the sequence for you (`max_wait_beats`, default 6, giving a
60-minute ceiling at the default beat quantum).
The lead consumes the deliverables and routes them into gate-1 exactly
as before; nothing is detached and no gate is skipped.

The deliverable path for each teammate is the one recorded in the
snapshot's **In-Flight Teammates** row at dispatch — the same path, and
the same handle, that survives a compaction.

A blocking (`run_in_background: false` / omitted) dev dispatch is a
lead-conduct retro finding: it reintroduces a window in which the
operator cannot be heard. `scripts/ai-dlc/validate-steering-budget.sh` fails
the gate on it.

**Bounded-join ≠ serial execution.** The beat governs HOW the lead
waits on a dev, NOT how MANY run at once. Independent stories MUST be
dispatched in parallel — in ONE message, each in its own worktree, then
beat-joined on all results. Parallelism comes from per-story worktrees
plus the join. The lead SHALL serialize two stories ONLY on a
real dependency: a shared source file both stories write, or a
by-content gate dependency (story B's gate-1 reads story A's merged
output). Before the first dispatch the lead MUST emit, as a written
planning output, a **story dependency-DAG + wave plan**: for each
story, the files it owns and the stories it genuinely depends on, with
wave grouping derived from it (independent stories → same wave /
parallel; shared-file or by-content chains → serialized land-order). A
default-to-serial dispatch the operator must challenge to parallelize,
or a missing / after-the-fact wave-DAG, is a lead-conduct retro
finding.

**Minimum mechanism (Rule 26(c)) — the wave-DAG planning output.**
Failure caught: silent over-serialization — independent stories queued
behind a chain they share no files with, wasting wall-clock and
parallel capacity; and its inverse, parallel dispatch of two stories
that write the same file, causing merge thrash. False-positive cost:
one written dependency-DAG + wave grouping per sprint before dispatch.
Removal condition: retire once dispatch parallelism is derived
mechanically from a per-story file-ownership manifest rather than lead
judgment.

**Dispatch-prompt cache discipline.** When dispatching multiple
teammates (parallel devs, or a dev plus QA on the same story), order
each dispatch prompt as a **stable shared block first, variable tail
last**. The shared block — sprint conventions, architecture pointer,
the Rule 19(b) role-contract line (*"Your operating contract is
`.claude/team-roles/<role>.md`. Read it and follow it as your FIRST
action…"*), branch/merge protocol — MUST be byte-identical across every
dispatch of the same role in the sprint. Put only the per-story content
(worktree path, story id, acceptance criteria, dev-brief findings)
after it. Prompt-cache entries are content-addressed: an identical
leading block means the first dispatch writes it and every later
dispatch reads it from cache instead of re-writing. Reordering or
re-wording the shared block per dispatch defeats this and forces a
cold write on each spawn.

**Dev-brief bug-class checklist.** When the dev-brief includes a
bug-class finding from the code-reviewer (see `code-reviewer.md`
bug-class audit mandate), the dev MUST grep for same-shape call-sites
listed in the finding and verify each one in the fix commit. The
dev record MUST cite the grep command and match count. Partial
enumeration (fixing the reported instance but not grepping for
siblings) fails gate-validation.

**Canonical-story-file pre-flight check before dev dispatch.** Before
dispatching dev for any story, the lead MUST verify two conditions:
(a) the canonical story file exists at
`_bmad-output/planning-artifacts/s<N>/stories/story-<M>-*.md`, where `<M>`
is the story INDEX and the sprint comes from the directory — a story file
carries no sprint token; (b) the
canonical story file is reachable on the dev's branch base (on `main`
or merged into the sprint branch before dev spawn). If (b) fails
because the canonical spec lives on an unmerged PR, the lead MUST
either merge that PR first or pin the dev branch base to a commit
that includes it. Dispatching dev without both conditions satisfied
is a story-scope failure mode. Violation fails gate-validation
Check 22 on detection at retro.

**Dev-dispatch exploration budget.** Every dev brief MUST bound
exploration and force an early write. The brief MUST state: (a) an
explicit read ceiling (default: ≤15 file reads before the first code
write); (b) a mandatory early-scaffold commit — commit function
signatures and file structure before filling bodies, so a mid-work
interruption loses body-fill, not the entire output; (c) if the dev
nears its budget without committed code, it MUST priority-order the
remaining acceptance criteria, implement top-down, and report
DONE-vs-REMAINING per AC. A brief omitting (a)+(b)+(c) is
dispatch-incomplete.
