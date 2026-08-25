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

Execute this 5-step procedure in order:

1. **Stop all in-flight teammates first.** Call `TaskStop` on
   every `in_progress` task. Halt any Agent-spawned teammate not
   bound to a task. Wait until every teammate has returned before
   proceeding. Record stopped teammates and in-flight artifacts
   in the snapshot's Open Items in Step 3.
2. Commit any in-flight work (`git add` + `git commit`), including
   work teammates left in the working tree.
3. Finalize the pipeline snapshot — one last update capturing
   anything not yet reflected, including the stopped-teammate
   record from Step 1. Commit the finalized snapshot if the project
   tracks `_bmad-output/`, then push the current branch to origin
   (`git push`) so the Step 2 commit and the finalized state reach the
   remote and are not stranded on this machine. **Push in the foreground
   with `timeout: 600000`** — `_gate-procedures.md` ("Auto-handoff
   evaluation", step 3) owns why, and the reason is not restated here.
   If the push fails (no
   remote configured, offline, or a protected branch), report it to the
   operator in one line and continue; the local commits still stand and
   the handoff is not blocked.
4. Emit the successor's entry line — exactly `/ai-dlc resume`, wrapped in
   `----` delimiter lines (one before, one after) for copy-paste. Nothing
   else: no narrated body. If auto-session-chaining is in use, also
   `touch _bmad-output/.driver/handoff` (the driver's zero-content handoff
   signal).
5. Create the pause flag so the continuation hook allows this session to
   end cleanly: `touch _bmad-output/pipeline-paused.flag`. Then end the
   session — do not continue the pipeline in this conversation.

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
