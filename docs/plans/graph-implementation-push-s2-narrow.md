# DISCHARGED — DO NOT EXECUTE — narrow graph's `implementation-push.md` §2 to its graph-local points

**Discharged by graph's own run: `d82236cee`, "narrow implementation-push §2 to graph-local points" (#1227), on graph
`main`.** See `## Discharge`.

## RESUME HERE

**SPENT: graph ran this plan as #1227; see `## Discharge`. What follows is the state at writing.**
**STATE AT WRITING: WRITTEN AND REHEARSED, NOT STARTED.** Requested by the graph session after
graph's 0.789.0 pull (#1226) closed `PC-S319-IMPLEMENTATION-PUSH-WORKTREE-EXPLICIT-DISPATCH-BLOCK-RESTATES-CORE-DISPATCH-PROTOCOL`.
That entry's "local work remaining" is this file's subject. The operator moved it out of sprint
work and wants it done between sprints. **It runs only after the operator approves it.**

**A graph session reads this file at its ABSOLUTE path,
`/Users/n8/git/ai-dlc/docs/plans/graph-implementation-push-s2-narrow.md`.** From a session rooted in
the consumer, the relative path in the one-liner resolves against the consumer and finds nothing.

**The rehearsal figures are expectations.** They come from a `file://` clone of graph at `main`
`b3f2fe199`, installed 0.789.0. A disagreement with `## Rehearsal` is a STOP-and-ping.

Read `## Start here` first, then `### Numbered actions`.

## Start here

- **`/Users/n8/git/graph`**: the consumer, and the ONLY tree this change writes. It lands through
  graph's normal branch, PR and merge, and the graph session executes it. Both files are
  consumer-owned extensions (`core-paths.sh --is-core` exits 1 on each), so no distribution
  release is involved.
- **`/Users/n8/git/ai-dlc`**: the distribution. READ ONLY from the graph session:
  read it, never write it.

**The consumer's tree is dirty with `_bmad-output/` pipeline state, and that is expected.** Do not
commit, revert, stash or clean it. Stage only the two files named below.

**The two files.** Both are under `/Users/n8/git/graph/.claude/skills/ai-dlc/extensions/steps-domain/`:

- `implementation-push.md` (`push_candidate: true`). Its block 1 is the §2 "Worktree-explicit dev
  dispatch (CO-S173-RV-11)" section, points 0-10. That block is DELETED whole.
- `implementation-domain.md` (`push_candidate: false`). It hooks the same core file,
  `steps/implementation.md`, at the same `conforms_to: 20`, and already holds graph's other §2
  dispatch blocks. The graph-local residue is APPENDED here as one new block.

**Why relocate rather than edit in place (constraint 1).** `push-drain.sh` joins a block to a
refusal on its digest alone (`core/skills/ai-dlc-update/reconcile/push-drain.sh:21`). Any edit to
block 1 inside the `push_candidate: true` file gives it a new digest, and the next pull reads it as
`PUSH-CANDIDATE` again, a new proposal of points core has already ruled graph-local. Moving the
residue into the `push_candidate: false` sibling takes it out of the drain entirely. The four
remaining `-push` blocks keep their digests byte-for-byte, so they still read `PUSH-REFUSED`.
Appending to the existing sibling is smaller than a new extension file, which would need its own
frontmatter and its own layer-adjudication history.

### Point-by-point disposition

Core text is at the distribution's `main` (0.789.0). Each "core" cell names where the point lives.

| § 2 point | disposition | where core carries it |
|---|---|---|
| preamble (`isolation: worktree` is unreliable) | DROP | `core/skills/ai-dlc/steps/_dispatch-protocol.md:18`, verbatim |
| 0. commit planning artifacts before pre-creating worktrees | DROP | `_dispatch-protocol.md:24`, same rule |
| 1. pre-create a worktree per story (command) | DROP the rule, KEEP the absolute sibling-path form | `_dispatch-protocol.md:31`; core's command spells the path relatively |
| 1. `git branch -D` after `git worktree remove` | KEEP | not in core; batch 232 ruled it a graph-local NOTE |
| 2. branch off the current sprint-branch HEAD | DROP | `_dispatch-protocol.md:34` |
| 3. absolute worktree path in the brief, first-action `cd` | DROP | `_dispatch-protocol.md:37-44`, which is STRICTER: it says a first-action `cd` alone is not compliance |
| 4. `git -C` on every git command | DROP | `_dispatch-protocol.md:41-44` |
| 5. one story per dev, `SendMessage` `to: "main"`, go idle | DROP | `_dispatch-protocol.md:49-51` |
| 6. serialize between waves | DROP | `core/skills/ai-dlc/rule-bodies/rule-28.md:164`: each wave is joined before the next spawns |
| 7. `git worktree list` check before merge-back | KEEP | not in core; batch 232 ruled it redundant once `git -C` holds, a NOTE, so keeping it is graph's choice |
| 8. `PI-S169-6` / `lead_only: true` not dispatched to dev | KEEP | graph-local; `scripts/ai-dlc-local/validate-story-frontmatter.sh` reads the flag |
| 9. "Do not commit `_bmad-output/**`" brief line | KEEP | graph-local; core's dev rule is narrower (`core/team-roles/dev.md:58`) |
| 10. `git stash` ban as a standing line | DROP | `_dispatch-protocol.md:60-71`, same standing line |
| closing "Violation is a rule-compliance finding…" | KEEP | graph's retro audit hook |

**Points 8 and 9 contradict core, and keeping them is deliberate (constraint 3).** Core routes
protected-path stories to a delegable `protected-path-editor` (`core/skills/ai-dlc/steps/implementation.md:71`)
and lets a dev commit the status marks the workflow assigns it. Graph's versions are stricter.
Dropping either would change graph's dispatch behaviour, which KISS forbids here. Changing them is
a separate operator decision, and this plan does not make it.

### The block to append to `implementation-domain.md`

Append exactly this, after the file's last line, with one blank line before the heading:

```
## §2 Worktree dispatch — graph-local additions (CO-S173-RV-11)

Core's "Worktree-explicit dev dispatch" in `steps/_dispatch-protocol.md`
governs dev dispatch. These points are graph-local and add to it:

1. Dev worktrees are siblings of the repo, at an absolute path:
   `git worktree add /Users/<u>/git/<repo>-s<N>-story-<X> -b dev/sprint-<N>/story-<X> <sprint-branch-HEAD>`
2. When tearing down and recreating a worktree, the lead MUST
   `git branch -D dev/sprint-<N>/story-<X>` after `git worktree remove`
   — `git worktree remove` does NOT delete the branch, and recreating
   with `-b` against the lingering branch fails.
3. Lead verifies isolation BEFORE merging back: `git worktree list`
   MUST show one entry per active dev. If shared-CWD recurrence is
   detected, ABORT and escalate.
4. `PI-S169-6` protected-path enforcement applies at dispatch: stories
   with `lead_only: true` MUST NOT be dispatched to dev. Lead executes
   in the main worktree.
5. Dev brief MUST include: "Do not commit `_bmad-output/**`. Emit
   pipeline-state updates as text in your completion report."

Violation is a rule-compliance finding surfaced at the retro rule-file audit.
```

### Numbered actions

1. **Confirm the operator has approved THIS change and the pipeline is between sprints.** If the
   snapshot shows a sprint in implementation, STOP and ping: the operator chose between-sprints
   because a running sprint reads this rule file.
2. **Record the pre-edit state, in one invocation.** Run
   `bash .claude/skills/ai-dlc-update/reconcile/push-drain.sh --digest .claude/skills/ai-dlc/extensions/steps-domain/implementation-push.md`
   from the graph root. Expect 5 rows, with block 1 digest `b0e3cc6b32827bc2e5926bf2bf5130840ac14ec3`.
   Also record `md5 -q` of both files and `git status --porcelain | wc -l`. If block 1 reads any
   other digest, someone has edited it since the pull: STOP and ping.
3. **Cut a branch from graph's `main`** by graph's own convention (for example
   `chore/narrow-implementation-push-s2`). Do not switch away from a branch with in-flight work;
   if `main` is not checked out, ping first.
4. **Make the edit.** In `implementation-push.md`, delete from the line
   `## §2 Worktree-explicit dev dispatch (CO-S173-RV-11)` up to, but not including, the line
   `## §2 Dev-brief bug-class checklist mandate (CO-S173-RV-17)`. Leave the frontmatter, line 9 and
   blocks 2-5 untouched. Append the block above to `implementation-domain.md`. Use the Edit tool,
   not `sed`: the block carries backticks and an em dash.
5. **Verify, every command from the graph root, against `## Rehearsal`:**
   - `push-drain.sh --digest` on `implementation-push.md`: 4 rows, digests `be4a1031…`,
     `67934240…`, `e5cc0af2…`, `3205b931…`, the same four as blocks 2-5 before.
     **Control:** `grep -c b0e3cc6b` over that output reads 0, while the same grep over action
     2's saved output reads 1.
   - `push-drain.sh /Users/n8/git/ai-dlc 7e8d62d7 /Users/n8/git/graph`: 4 rows, all `PUSH-REFUSED`,
     0 `PUSH-CANDIDATE`. The installed copy at
     `.claude/skills/ai-dlc-update/reconcile/push-drain.sh` is byte-identical to the
     distribution's, so either may be run.
   - `push-drain.sh --digest` on `implementation-domain.md`: 3 rows. Block 3 is the new heading,
     digest `bf81ce4320e99e434497571a4ddc5ae1f18b9630` if the text was copied exactly. A different
     digest means the copy differs; diff it against the block above before going on.
   - `bash scripts/ai-dlc/validate-layer-entries.sh .` exits 0 with output byte-identical to a run
     taken before the edit (save one in action 2).
   - `layer-drift.sh --list-adjudications /Users/n8/git/ai-dlc c96ad358 7e8d62d7 /Users/n8/git/graph`,
     run from the graph root, before and after the edit: 9 keyed subjects both times and no
     `HARD-*` row. Both implementation entries read `EXTENSION-OK`. The base is the PREVIOUS
     install (0.788.0), on purpose. The installed `commit:` now equals `7e8d62d7`, and base equal
     to theirs is a degenerate range that hides every drift-keyed subject. A note on stderr about
     that is not a disagreement.
6. **Commit only the two files**, open the PR, and run graph's own gate as graph always does.
   The rehearsal did not run graph's pre-push suite, so its result and wall clock are unknown.
   A red that names a file other than these two is graph's own state; ping rather than fix it here.
7. **Merge only with the operator's approval**, as graph's process requires.
8. **Report to the operator**: the PR, the action 5 figures beside `## Rehearsal`, the gate
   verdict, and any disagreement. Then fill in `## Discharge` below as text in the report. This
   file lives in the distribution, so the graph session does not edit it.
9. **AFTER THE MERGE, BEFORE YOU STOP: re-derive this file's own `## RESUME HERE` block.** This
   action and every one after it are for a distribution-side session, which the operator hands
   them to. Re-run action 5's commands against graph's merged `main`, read-only, DIFF every
   figure against `## Rehearsal`, and fix the COMMAND where they disagree, never only the prose.
   Fill in `## Discharge` from the graph session's report and retitle this file as spent.
10. **The fresh-resume check.** After action 9's docs commit has merged, read this file from a
    fresh checkout of the distribution's `origin/main` as a stranger, confirm it reads as spent
    there, and run `bash scripts/validate-plan-shape.sh` there as the floor.
11. **Hand the ledger plan to a local ai-dlc session, then stop.** `ListAgents`; if a local
    `ai-dlc-*` session is found (never a `graph-*` one), send it with `SendMessage` exactly
    `READ and FOLLOW docs/plans/graph-ledger-full-drain.md` and nothing else. If none is found,
    there is nothing further to do.

### Ping the operator

On any question, on any decision, on completion, and on any early stop. From outside, a session
that is thinking and a session that is waiting on a human look identical.

### Done when

Each is observed at the point named, by the graph session, from the graph root.

1. **After action 4, before commit**: `push-drain.sh` at `7e8d62d7` prints 4 rows, all
   `PUSH-REFUSED`, and `grep -c b0e3cc6b` over the `--digest` output reads 0 against action 2's 1.
2. **After action 4**: `validate-layer-entries.sh` output is byte-identical to action 2's (`cmp`
   exit 0), and the `layer-drift.sh` classify histogram is unchanged.
3. **After the PR merges**: graph `main` carries both edits. Check with `git show main:<path>` and
   the two `--digest` outputs above.

All three were reached on the rehearsal clone.

## Hazards

- **An edit left inside `implementation-push.md` re-opens the candidate.** The drain keys on the
  digest, so a "small" tidy of block 1 is a new `PUSH-CANDIDATE` on the next pull. The block
  leaves that file whole, or not at all.
- **Do not touch blocks 2-5 or the frontmatter of `implementation-push.md`.** Their refusal rows
  key on their current digests, and a whitespace change inside a block moves its digest.
  Whitespace BETWEEN blocks does not, because runs are collapsed, but do not rely on that.
- **The layer-adjudication register's verdicts for both entries become spent.** Their subject
  digest covers the entry file, so the next pull whose range changes `steps/implementation.md`
  asks for an `LC-E4` verdict on both entries, which it would ask anyway. No verdict is owed now:
  the hooked core file is unchanged and the rehearsal produced 0 new keyed subjects.
- **The Bash tool's shell is zsh.** No `PIPESTATUS`, so `cmd | tail` reports `tail`'s status.
  Never read an exit code through a pipe.

## Rehearsal

Run on a `file://` clone of graph at `main` `b3f2fe199` (installed 0.789.0, `commit: 7e8d62d7`),
with the distribution at `7e8d62d7`. The edit was applied by script, exactly as action 4 states.
The real graph tree was checked after: porcelain count unchanged at 10, and
`git diff --stat -- .claude/skills/ai-dlc/extensions` empty.

| check | before | after |
|---|---|---|
| `push-drain.sh` drain at `7e8d62d7` | 5 `PUSH-REFUSED` (block 1 `b0e3cc6b…`) | 4 `PUSH-REFUSED`, 0 `PUSH-CANDIDATE` (the old blocks 2-5, same digests) |
| `implementation-domain.md` blocks | 2 | 3, new block digest `bf81ce43…` |
| `validate-layer-entries.sh` | exit 0 | exit 0, output identical (`diff` exit 0) |
| `layer-drift.sh --list-adjudications`, base = old install `c96ad358` | 9 keyed, 9 recorded | identical |
| `layer-drift.sh --list-adjudications`, base = `7e8d62d7` | 8 keyed | identical |
| `layer-drift.sh` classify, both bases | 46 / 47 rows, 0 `HARD-*` | identical histograms; both entries `EXTENSION-OK` |

**Control for the layer comparison:** the edited clone's `implementation-push.md` differs from
graph's (`cmp` exit 1), so the two sides read different trees. A first cut that dropped point 9
moved one `validate-layer-entries.sh` line (86 artifact-path prescriptions read to 85), which shows
that validator can see this edit. With point 9 kept, it reads 86 both sides.

**Not rehearsed:** graph's pre-push suite and its wall clock, and the PR flow.

## Discharge

Executed 2026-10-15 by the graph session. Per that session's report, the operator approved it; that was not checked
from here. It merged as graph #1227 (`d82236cee`), changing
only the two extension files (+22 / -63).

- **Graph session's report:** every action 5 figure matched `## Rehearsal`, including the before and after `cmp` 0 on
  `validate-layer-entries.sh`, `--list-adjudications` (9 keyed) and the classify histogram (46 rows, 0 `HARD-*`). Graph's
  pre-push suite read `all gates green` with 0 FAIL lines. A grep of graph's live docs for the deleted heading found 0
  hits; as the control, the heading counted 1 in core's `_dispatch-protocol.md`. No disagreement was reported.
- **Re-derived here, read only, against graph `main`:**
  - `--digest` on `implementation-push.md` gives 4 rows, `be4a1031…`, `67934240…`, `e5cc0af2…` and `3205b931…`. `b0e3cc6b`
    counts 0 there against 1 at `d82236cee^`.
  - `implementation-domain.md` has 3 blocks, the new one at `bf81ce4320e99e434497571a4ddc5ae1f18b9630`.
  - `push-drain.sh` at `7e8d62d7` reads 4 `PUSH-REFUSED` and 0 `PUSH-CANDIDATE`.
  - `validate-layer-entries.sh` exits 0.
- PC-S319's "local work remaining" is discharged. Graph left its ledger archive unedited.
