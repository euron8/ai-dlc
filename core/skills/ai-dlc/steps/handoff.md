---
name: handoff
description: The human-requested (path a) handoff procedure — stop teammates, commit, finalize snapshot and push to origin, emit resume line, pause. Loaded at a handoff seam; terminal.
nextStepFile: STOP
---
<!-- STEP_LOADED_TOKEN: handoff -->

# Handoff Procedure (path a — human-requested)

Loaded when a path (a) handoff fires (SKILL.md Rule 2 / Handoff
Protocol "Handoff triggers"). The lead reaches this file by an explicit
user handoff request (directly, or in response to a Rule 2(b)/(c)
reminder), or by auto-handoff (SKILL.md "Auto-handoff") executing the
path (a) procedure unchanged at a safe seam. Rule 11(b) preamble
applies. Only path (a) initiates a handoff; paths (b)/(c) are reminders
only.

Reading this file recorded `_bmad-output/.handoff-in-progress`
(`ai-dlc-handoff-entry.sh`). You do not create it. A compaction can land on
any turn of the five steps below, and that marker is what routes the
post-compact Read back to THIS file rather than to the step the handoff
interrupted — the snapshot still names that step, correctly, until step 3
rewrites it. Step 5 removes the marker.

Execute this 5-step procedure in order:

1. **Stop all in-flight teammates first.** Call `TaskStop` on
   every `in_progress` task. Halt any Agent-spawned teammate not
   bound to a task. Wait until every teammate has returned before
   proceeding. Record stopped teammates and in-flight artifacts
   in the snapshot's Open Items in Step 3, and set each stopped
   teammate's **In-Flight Teammates** row `status` to `stopped`.
   **Rewrite the row; do not delete it** — at a handoff the successor
   needs to know what was running, and a deleted row is
   indistinguishable from a teammate that never existed.
   `ai-dlc-continue.sh` Check 0 blocks the stop while any row still
   reads `in-flight`.
2. Commit any in-flight work (`git add` + `git commit`), including
   work teammates left in the working tree.
3. Finalize the pipeline snapshot — one last update capturing
   anything not yet reflected, including the stopped-teammate
   record from Step 1. Commit the finalized snapshot if the project
   tracks `_bmad-output/`, then push the current branch to origin
   (`git push -u origin HEAD`) so the Step 2 commit and the finalized
   state reach the remote and are not stranded on this machine.
   **`-u origin HEAD`, never a bare `git push`.** A bare push cannot
   succeed on a branch that has never been pushed — which is every
   sprint's FIRST handoff wherever a branch is cut per sprint — and it
   fails with `fatal: The current branch <b> has no upstream branch`.
   `ai-dlc-update`'s step 1 has resolved this exact state with the `-u`
   form all along; two step files disagreeing about one command is what
   made this survivable. **Push in the foreground
   with `timeout: 600000`** — `_gate-procedures.md` ("Auto-handoff
   evaluation", step 3) owns why, and the reason is not restated here.
   If the push fails (no
   remote configured, offline, or a protected branch), report it to the
   operator in one line and continue; the local commits still stand and
   the handoff is not blocked. **Those three are ENVIRONMENTAL and are
   the whole of what this fallback covers. A branch that cannot be
   published is not one of them** — routing it here is what discarded a
   sprint's planning artifacts and party-mode transcripts, leaving them
   in git nowhere while the handoff reported success and emitted a
   resume line for a successor with nothing durable behind it. And
   "the local commits still stand" is false whenever Step 2 was also
   skipped, so verify Step 2 landed before relying on this sentence.
4. Emit the successor's entry line — exactly `/ai-dlc resume`, wrapped in
   `----` delimiter lines (one before, one after) for copy-paste. Nothing
   else: no narrated body. Then `touch _bmad-output/.driver/handoff` —
   the driver's zero-content handoff signal.

   **The `touch` is unconditional.** A session cannot tell from inside
   itself whether a driver is attached, so a conditional here is a
   condition nobody can evaluate. With no driver the marker is inert —
   nothing reads it; with one, the driver consumes and deletes it.
5. Create the pause flag so the continuation hook allows this session to
   end cleanly: `touch _bmad-output/pipeline-paused.flag`, and clear the
   entry marker from the preamble: `rm -f _bmad-output/.handoff-in-progress`.
   Then end the session — do not continue the pipeline in this conversation.

   **The marker is cleared here and nowhere earlier.** It means "inside this
   procedure", so removing it at step 3 or 4 would blind the recovery for the
   steps that are still to run — which are exactly the steps that have been
   skipped. If a later session finds it present with the pause flag gone, the
   resume path has already cleared the pause and the marker is stale; delete
   it and continue.

**Resume is snapshot-driven.** The entry line is the bare skill
invocation; the resume path (`route.md` Step 0) reads
`_bmad-output/pipeline-snapshot.md` for ALL state. Do NOT narrate
pipeline state (sprint, branch, step, open items, decisions) into the
resume line — the snapshot is the single source of truth, and any
handoff-only instruction that is not derivable from other snapshot fields
belongs in the snapshot (step 3), not the resume line.

```
----
/ai-dlc resume
----
```
