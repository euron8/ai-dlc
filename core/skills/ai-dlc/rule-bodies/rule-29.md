### Rule 29 -- Steering budget: the operator must always be able to reach you

This file is the full text of Rule 29 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

Claude Code delivers a queued operator message at a **tool-call boundary** --
it arrives alongside the next tool result. A long turn is therefore harmless.
What silences the operator is a long **single tool call**: while one is in
flight there is no boundary, so the message cannot land. The operator's blind
window equals the duration of the in-flight foreground call.

`Agent` is the only unbounded foreground primitive you control. `Bash` and
`TaskOutput` are capped by the harness at 10 minutes; `AskUserQuestion` is the
operator's own think-time. (`SendMessage` is not a dispatch primitive at all --
it reaches a teammate `Agent` already spawned, under the scope bound Rule 28
sets. It never substitutes for a spawn.) A blocking `Agent` call is therefore the one way you
can hold a human's message hostage -- and before this rule, ai-dlc *mandated*
it. Measured across 278 consumer sessions: 355 foreground `Agent` calls blocked
longer than 2 minutes, the worst for **36 minutes**.

**The invariant.** No foreground tool call may block longer than the steering
budget (`steering_budget`, default **120 seconds**).

**Bounded-join dispatch.** Spawn teammates with `run_in_background: true`, then
JOIN them by arming a bounded, **backgrounded** wait-beat and ENDING YOUR TURN.
The beat's exit re-invokes you -- the harness re-invokes a session when a
background task it spawned exits -- so the wait runs off the foreground entirely:
a *yielded* lead has no in-flight foreground call at all, and a queued operator
message lands on the very next turn, sooner than it would while you sat out a
foreground beat.

**Which join, and this is not a preference -- one of them does not work.**

`Agent` returns an **`agent_id`** (`<name>@session-<id>`). `TaskOutput` joins a
**`task_id`**, which only `TaskCreate` produces. **`TaskOutput` cannot join an
`Agent` spawn.** Handed an `agent_id` it returns `No task found with ID: ...` and
you have burned a call and learned nothing. `validate-steering-budget.sh` Check D
flags it.

So:

- **Teammates (`Agent`) -- join on the DELIVERABLE.** Every ai-dlc teammate delivers
  by file (Rule 20, "File-write deliverable"), so the file *is* the handle. Wait for
  it with the **bounded file-wait beat** below. This is the join for the overwhelming
  majority of ai-dlc dispatches -- analyst, adversary, dev, qa, code-reviewer, and
  every party-mode persona.
- **Tasks (`TaskCreate`) -- join on the `task_id`.** Only here is `TaskOutput` right:

      TaskOutput(task_id, block: true, timeout: 120000)

  Each beat returns within the budget with the task's result, or `status: running`.
  Not finished? Beat again.

The bounded file-wait beat is therefore not a fallback or a special case for `Skill`
spawns -- it is the primary join for teammates.

What this does NOT change:

- **The join is preserved.** You still consume the teammate's result before
  routing it into the next gate. Nothing is detached; a gated cycle stays
  gated. Only *how you wait* changes.
- **Rule 3 is preserved -- by the armed beat, not by refusing to yield.** A join
  is a bounded WAIT; you conduct it by arming a backgrounded wait-beat and then
  ending your turn. When that beat exits -- on delivery, or at its budget -- the
  harness re-invokes you, so the yield is never a stall. The Stop hook
  (`ai-dlc-continue.sh` Check 2b) lets your turn end for exactly as long as a
  live beat is sleeping. **The one hard invariant: never end your turn on an
  outstanding join without a live backgrounded beat armed** -- that, not the
  yield itself, is what would trade a queued prompt for a dead pipeline.
- **Parallelism is preserved.** Dispatch the whole wave in ONE message, then
  beat-join each teammate (`implementation.md`).

`run_in_background: true` is now the DEFAULT for every spawn, not an exception.

A `Bash` call you expect to exceed the budget runs `run_in_background: true`
and is polled the same way.

**The bounded file-wait beat.** The join for every file-delivering spawn -- which,
under Rule 20, is every teammate ai-dlc has. Neither shape hands you a `task_id`:
an `Agent` returns an `agent_id` that `TaskOutput` will not take, and a `Skill`
returns nothing at all (`/bmad-party-mode` spawns its personas INSIDE the
sub-skill, Rule 20(i), so the lead holds no handle whatsoever). Both deliver by
file write (Rule 20, "File-write deliverable"), so the file IS the handle, waited
on in beats:

**Do not retype the loop. Call the script -- and pass the WHOLE WAVE to ONE call,
`run_in_background: true`:**

    Bash(run_in_background: true):
      scripts/ai-dlc/wait-for-deliverable.sh <path> [<path>...]

    exit 0 -- BEAT COMPLETE. This call WAS the beat. READ THE OUTPUT:
              `DELIVERED <path>` lines are yours to consume; `WAITING
              <path>` lines are still out -- beat again over those.
              Exit 0 does NOT mean everything landed.
    exit 1 -- NON-DELIVERY. Sequence exhausted: re-dispatch ONCE (then
              re-run with --reset), and if it fails again, HARD_BLOCK.

**One Bash call, one beat -- however many deliverables.** All paths poll inside
the same beat. Never chain beats (`wait a.md; wait b.md`) into one `Bash` call:
two beats is two budgets, the call overruns, and the harness backgrounds it --
Check A starvation committed by the caller instead of by the loop. The script
refuses to sleep twice in one call; the right shape is one call carrying every
path.

It enforces both bounds so you do not have to hold them:

- A beat is ONE `Bash` call, run in the background (`run_in_background: true`),
  that returns within the **beat quantum** (`AI_DLC_WAIT_BEAT_SECS`, default
  **600 seconds**). It polls every 10s inside itself and exits the moment every
  path it is joining has landed, so delivery re-invokes you within 10 seconds --
  the quantum only bounds how long a STILL-WAITING join sleeps before waking you
  with nothing to consume. While it sleeps you have ended your turn, so a queued
  operator lands immediately.
- **The beat quantum is not `steering_budget`.** `steering_budget` (still **120
  seconds**) bounds a FOREGROUND call, because the operator cannot be heard while
  one is in flight. A backgrounded beat gags nobody, so it is not bound by it.
- Bound the **sequence**, not just the call: `max_wait_beats` (default **6**,
  giving a 60-minute ceiling at the default quantum). Exhaustion means the file
  is absent, which Rule 20 already defines as non-delivery -- **re-dispatch**
  once, then HARD_BLOCK. The wait never runs forever. The script counts the
  beats in a sidecar keyed by the deliverable, so the sequence terminates
  whether or not you remember it.
- **An exhausted clock is not evidence of death.** Pass `--progress-path <the
  teammate's worktree>` and a beat that would declare non-delivery instead
  EXTENDS the sequence by one beat while files under that path keep changing,
  printing `PROGRESS`. Grants are capped at `max_wait_beats` too, so the wait
  still ends. Never point it at `_bmad-output` -- the script refuses, because it
  writes there itself and progress would then always be true.

**Minimum mechanism (Rule 26(c)) -- `wait-for-deliverable.sh`.** Failure caught:
(i) a hand-typed wait, in the foreground, that outlasts the steering budget and
gags the operator (Check A); and (ii) a hand-typed wait with no sequence bound,
which advances nothing forever (Check C). The script can commit neither -- the
beat is clamped inside the quantum, and beats are counted in a sidecar so
exhaustion declares Rule 20 non-delivery. `--progress-path` extends that
sequence on observed work, and its grants are counted against the same bound, so
the wait stays finite and this sentence stays true. False-positive cost: a
deliverable landing in the same second the sequence exhausts is re-dispatched
once; `--reset` re-arms it, and `--progress-path` removes most of the reason to
reach for `--reset` on a hunch. Removal condition: retire when the harness offers a join
primitive that takes the handle an `Agent` actually returns.

Check A (duration) and Check C (count) bind different things: an over-budget
call is a window in which the operator cannot be heard; an unbounded beat
sequence advances nothing forever. An unbounded wait is a hang, not a gag.
**The loop goes in the beat count, never inside the call.** (Now that the beat
is backgrounded, `validate-steering-budget.sh` Check C sees fewer *foreground*
wait-shaped calls; the sequence bound lives in the sidecar counter, where it
already did. Do not read a quiet Check C as "leads stopped over-waiting.")

**When the operator does reach you, answer them.** An operator message sets
`_bmad-output/pipeline-paused.flag` (UserPromptSubmit hook). While it exists
you MUST NOT advance the pipeline -- the `PreToolUse` hook denies `Agent`,
`Skill`, `TaskCreate`, and `_bmad-output/` writes until you deal with it. Read
the message, respond in text, then classify: resume intent -> `rm -f
_bmad-output/pipeline-paused.flag` and re-read the step file (Rule 22);
question or correction -> answer it and leave the flag set; the operator is
steering. Rule 3 does not override this. Rule 3 forbids stalling when no one
is waiting on you. Here a human is.

**Minimum mechanism (Rule 26(c)).** Failure caught: (a) the lead blocking on a
long foreground `Agent` call, during which the operator physically cannot be
heard; (b) the lead receiving a steer and executing straight through it, the
pause flag having had teeth in no hook; (c) the lead waiting on a Skill-spawned
deliverable with a single open-ended `until [ -s ... ]; do sleep; done`, which
runs to the harness's 10-minute `Bash` cap and returns `TIMEOUT` having learned
nothing; (d) the lead calling `TaskOutput` on an `Agent` -- `Agent` returns an
`agent_id`, `TaskOutput` takes a `task_id`, so every such call fails with `No
task found` and the lead falls back to a filesystem wait. Check D flags it.
False-positive cost: a few extra bounded-join beats per dispatch (p90 dispatch =
~3 beats), each a few hundred tokens. Removal condition: retire Check C if a
season of retros shows leads re-dispatch on exhaustion without it; retire the
whole rule when the harness bounds foreground tool-call duration itself, or
delivers queued input mid-call.

Enforcement: `scripts/ai-dlc/validate-steering-budget.sh` (Checks A, B, C, D) and
`.claude/hooks/ai-dlc-acknowledge.sh` (runtime deny).
