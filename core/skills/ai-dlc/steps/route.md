---
name: route
description: Detect pipeline variant from project state and user input, compose step sequence
nextStepFile: dynamically determined by routing logic
---
<!-- STEP_LOADED_TOKEN: route -->

# AI/DLC Router

`shard: n/a (no dispatch)` — this step routes to step files and joins prior deliverables.

## STATE VARIABLES
- `user_input`: The user's original request text
- `pipeline_variant`: One of [greenfield, feature, bug, carry-over, sprint-execute, brownfield-a, brownfield-b, brownfield-c, analysis-only]
- `has_product_brief`: boolean
- `has_prd`: boolean
- `has_architecture`: boolean
- `has_stories`: boolean
- `has_carry_over_items`: boolean
- `has_ready_sprint`: boolean (stories of the CURRENT sprint — the one `scripts/ai-dlc/sprint-status.sh sprint-id` resolves — have status ready-for-dev or in-progress; a story left in a closed sprint's block does not count)
- `is_ui_epic`: boolean (determined during planning, not routing)

## EXECUTION SEQUENCE

### Step 0: Entry-token and Resume Check

Before running the full routing sequence, read the entry token and check
for an existing pipeline snapshot that indicates a resume from a
previous session.

0. **If `user_input` is an ENTRY TOKEN, dispatch on it.** An entry token
   is the WHOLE of the user's input — optionally preceded by `/ai-dlc`
   and whitespace, and nothing else besides surrounding whitespace:

   - **`handoff`** — **READ AND FOLLOW** `steps/handoff.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) and skip the
     rest of this routing sequence.
   - **`resume`** — this is a resume signal for path 2 below. With the
     prefix it is `/ai-dlc resume`, which is the line `handoff.md` step 4
     emits verbatim, so it is the form a successor session actually
     arrives with. Accept that exact string.

   **`SKILL.md`'s handoff trigger (a) cannot cover the token form.** That
   trigger is a natural-language judgment a lead makes MID-SESSION, and a
   session whose FIRST input is the request has no lead in conversation to
   make it — so without this arm the request falls through to Step 1 and
   is routed as a new feature.

   **Match the WHOLE input, never a substring.** Measured over 67 recorded
   prompts from the reference consumer: a predicate matching any prompt
   CONTAINING `handoff` scores 9, and at least two of those are prompts
   ABOUT a handoff rather than requests for one — "the handoff that I
   issued should have pushed it", "you are not supposed to ask me if I
   want to handoff". Whole-input matching scores 6 with no false positive.
   A prompt that merely mentions the word is still covered mid-session by
   trigger (a), so the narrow predicate loses nothing.

1. Check if `_bmad-output/pipeline-snapshot.md` exists and is non-empty.
2. If YES and the user input carries a resume signal — the `resume` entry
   token above, OR input beginning with "Resuming an ai-dlc sprint", OR
   input explicitly referencing "pipeline snapshot" — this is a resume.
   **Before dispatching, run Step 0a snapshot integrity validation
   below.** If integrity validation passes:

   **The entry token is listed FIRST because it is the only one that has
   ever fired.** Across those same 67 prompts the other two forms match
   **0** and the bare entry line matches **3** — so a reader carrying only
   the prose forms has never once recognised a real resume, and the
   snapshot a handoff spent five steps preserving was archived as stale by
   Step 6 on the next invocation.
   - Take `current_step_file` from the snapshot Step 0a loaded. Do NOT
     re-read or re-grep the snapshot — that one load serves all of it.
   - Acknowledge the resume in the first output line:
     *"Resuming from snapshot at `{current_step_file}`."*
   - Reconcile every `In-Flight Teammates` row: a row whose `status` reads
     `stopped` is SKIPPED — that teammate was stopped deliberately, its
     deliverable is absent BECAUSE it was stopped, and re-arming it would
     re-dispatch work an operator chose to end. Read that arm first, because a
     stopped row also satisfies the absent test below. Otherwise: a deliverable
     newer than
     its `dispatched-at` is DELIVERED — consume it, never re-dispatch.
     Older or absent means the beat resumes, not that the teammate died.
     Arm that beat by running `scripts/ai-dlc/wait-for-deliverable.sh --complete --since <dispatched-at> <path>` when the deliverable is a seat, shard or cross file, and the same call without `--complete` for any other deliverable; when the row being re-armed is an adversarial shard, add `--shard-header convergence` for a shard under `shards/<artifact>-p<M>/` and `--shard-header elicitation` for one under `shards/<artifact>-elicitation/`, never for a repair dir; `run_in_background: true`, with `--since` set to that row's `dispatched-at` cell, because the teammate may have delivered before this session's join armed.
     Join the deliverable per `_gate-procedures.md`, "Bounded-join beat".
     Liveness for a teammate dispatched by a PRIOR session is unavailable
     to that program (`CLAUDE_CODE_SESSION_ID` differs), so its absence is
     not death.
     (A resume that followed `handoff.md` Step 1 finds the table carrying
     `stopped` rows and no `in-flight` ones — step 1 rewrites them and KEEPS
     them, per the In-Flight schema in `route-fresh-start.md` Step 6; one that followed a
     crash or context blow-out still carries `in-flight` rows. DISCHARGE the
     `stopped` rows once you have read them: delete them at your first
     snapshot write after this resume, one `scripts/ai-dlc/snapshot-update.sh
     --row-delete <agent>` per row, having carried anything they tell you
     into Recent Activity or Open Items with `--activity` or `--open-item`. They are a handoff RECORD with a
     reader, not permanent history, and nothing else ever removes them.)
   - Skip the rest of this routing sequence. Steps 1–6 are for fresh
     pipeline starts; on resume they would misclassify the input and
     overwrite the snapshot.
   - **READ AND FOLLOW** the step file named in `current_step_file` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`):
     `{project-root}/.claude/skills/ai-dlc/steps/{current_step_file}`
   - The snapshot is already current (kept fresh by
     `gate-validation.md` Check 14 on each gate passage throughout the
     previous session); do NOT re-initialize it.
3. If the snapshot exists but is EMPTY (0 bytes) and the input carries a
   resume signal, there is no state to resume: an earlier Step 6 was
   interrupted after the rotator archived the old snapshot and before the
   new one was written. Say so in the first output line, do not rebuild
   state from the archive, and continue to Step 1; Step 6 writes the new
   snapshot into the empty file.
4. If the snapshot exists but user input does NOT indicate a resume
   (e.g., the user is starting a new feature while an old snapshot
   remains on disk from a previous pipeline run), continue to Step 1.
   Do NOT read the stale snapshot's content: it describes a previous
   pipeline, and Step 6 absorbs it into the archive unread before
   creating a new one.
5. If no snapshot exists, continue to Step 1 normally.

### Step 0a: Snapshot Integrity Validation (resume dispatch only)

This sub-step runs only when Step 0 path 2 is taken (a resume). Do
NOT silently dispatch to `current_step_file` if any check below
fails. Surface the specific failure to the user with a proposed
remediation and wait for direction.

**On any failure, create the pause flag before surfacing:**
`touch _bmad-output/pipeline-paused.flag`. Waiting for direction is
an intentional pause, and the Stop hook only recognizes one by that
flag. The `/ai-dlc` invocation deleted it (see SKILL.md, "Clear the
pipeline pause flag before any other action"), so without this the
Stop hook treats the failure message as a Rule 3 stall and returns a
forced-continuation reason that argues for pairing the text with a
tool call -- pressuring the lead toward the very dispatch this
sub-step exists to prevent. The flag also lets
`ai-dlc-driver-signal.sh` emit `.driver/idle`, which parks an
auto-chained session for the operator instead of leaving it blocked.
The lead clears the flag when the user directs the resume.

The mechanical checks are one program. Run it first, from the project root:

`bash scripts/ai-dlc/resume-preflight.sh`

It runs check 1 (snapshot budget, `scripts/ai-dlc/verdict.sh validate-artifact-budget --only pipeline-snapshot.md`), check 3 (the six load-bearing sections by heading), check 4 (`current_step_file` exists under `.claude/skills/ai-dlc/steps/`), check 5 (recorded branch equals `git branch --show-current`), check 6 (`last_gate_passed` older than 7 days) and check 7 (stranded at `deploy-validate.md` on a sprint whose `sprint-status.yaml` says `status: done`; BOTH clauses are required, because `status: done` alone fires on every mid-retro resume). It stops at the first failing check and prints `PREFLIGHT FAIL check <n> <name>: <detail> | replies: <set>`; exit 1. Exit 0 prints `PREFLIGHT OK` and any `PREFLIGHT INFO` lines. Exit 2 is a refusal: surface it as a failure.

**Check 2, loading the snapshot, is yours.** Read `_bmad-output/pipeline-snapshot.md` **in full** (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`). This is the single load that serves the Step 0 dispatch and the rest of the session. Run the script before the read: check 1 protects it, because resume skips Steps 1–6, so Step 1a never runs and the next budget check is `gate-validation.md` Check 14, after the read.

**On a check 1 failure, apply the `trim` remedy the verdict names YOURSELF, without asking,** by the mechanics Step 1a's `trim` bullet gives (in `route-fresh-start.md`). Rule 25(a) in `SKILL.md` owns move-never-delete and the history destination, and `gate-validation.md` Check 14 owns the seven-section schema. If the verdict names a stamp later than the current UTC time, apply the stamp remedy its first FAIL line prints before any trim: rewrite each `FUTURE` stamp to `date -u` in place with `snapshot-update.sh --line-replace <section> <match> <text>` (or `--row-set <agent> dispatched-at <value>` for a teammate row), keep line order, and add the one `CLOCK CORRECTION` line that line spells with `--activity`. Then re-run the script. The trim performs the whole read check 2 needs, so it costs nothing extra. If the script still fails check 1, one mechanical pass did not close the gap: create the pause flag and HARD_BLOCK with the verdict line verbatim and the reply set `archive` (start fresh), `abort`, or name what to move.

**On any other failure, create the pause flag, then surface the line and wait for the operator's reply before dispatching:** `touch _bmad-output/pipeline-paused.flag`. Waiting for direction is an intentional pause, and the Stop hook only recognizes one by that flag. The `/ai-dlc` invocation deleted it (see SKILL.md, "Clear the pipeline pause flag before any other action"), so without this the Stop hook treats the failure message as a Rule 3 stall and pressures the lead toward the very dispatch this sub-step exists to prevent. The flag also lets `ai-dlc-driver-signal.sh` emit `.driver/idle`, which parks an auto-chained session for the operator. The lead clears the flag when the user directs the resume. Do NOT silently dispatch to `current_step_file` while a check fails.

**The replies.** On `edit` (check 3), add each missing section with `snapshot-update.sh --section-add <heading>`, then fill it with `--line-add`, `--activity` or `--open-item`. On `continue-here` (check 5), record it with `snapshot-update.sh --set branch <current_branch> 'Pipeline Position'`; on `switch`, run `git checkout {snapshot_branch}` and re-run the script. The seventh section, the teammate table Step 0 reconciles, AUTO-HEALS: if absent, create it empty with `snapshot-update.sh --section-add` naming its heading, say so in one line, and continue; the script does not check it, because a snapshot predating the section recorded no teammates and failing on it would strand every snapshot written by a prior version.

**Owed derivations (shown on every resume; not one of the seven pass/fail checks).** Run `scripts/ai-dlc/check-owed-derivations.sh`. Exit 0 can still print INFO lines (`INFO past-sprint` and `INFO history`), which are not open debt and never block, and an `UNMEASURED:` line (no record, or a record with 0 OWED rows), which means nothing was ever recorded as owed rather than that owed work was checked and found closed: show it, it passes; exit 1 prints one `OPEN` line per derivation an earlier pull left broken, and you show every line to the user with the resume summary. Exit 2 means the record is unreadable or malformed, or the current sprint could not be resolved: surface that line as a failure, since the rows are refused and unassessed. Exit 2 also means the LIVING sweep could not decide, because the validator gave no verdict for a file, or `core-paths.sh` or `--explain-cmd` is unavailable: re-run once the fault is gone, or reinstall ai-dlc. Also show every `INFO past-sprint` and every `INFO history` line (a row in an archive or an ai-dlc rotation output), each as unrepaired debt that is no longer enforced and is NOT closed. A row recorded after the planning gate is shown and carried but never refused — that is deliberate, so a sprint can always close; it is NOT closed. For the past-sprint kind, say this sentence verbatim: "Owed work recorded in a sprint that has since finished turns INFO and STOPS BLOCKING; an INFO row is unrepaired debt that is no longer enforced, and it is not closed." To close an OPEN row, append `REPOINTED<TAB><old file:line><TAB><new file:line><TAB>$ <new command>` to the record `_bmad-output/ai-dlc-update/owed-derivations.tsv`; the reader re-derives the new derivation on every read. An `OPEN` line whose 6th column is `living-sweep` is a fence in a LIVING document that reads an ai-dlc core file and no longer reproduces; show it with the other `OPEN` lines, and say that it closes only by re-running its command and rewriting the fence and its sentence in place, never by a record write, except in `_bmad-output/ai-dlc-update/push-candidate-ledger.md`, whose rows are immutable and close by a superseding row: a later derived fence in the same ledger carrying the same command, whose recorded output reproduces. The record is the only store: the snapshot carries no pointer to it, because Open Items is trimmed under budget, so run the reader rather than looking for one.

If the script printed `PREFLIGHT OK` (the snapshot is within budget, carries its sections, names a step file that exists, sits on its recorded branch, has a recent gate and is not stranded on a closed sprint) and check 2's read is done, continue with the Step 0 path 2 dispatch. Otherwise the user's reply directs the next action.

### Steps 1-6 and the failure modes: fresh start only

When Step 0 does not resume (no snapshot, a stale snapshot from a finished pipeline, or the operator chose `archive`), **READ AND FOLLOW** `{project-root}/.claude/skills/ai-dlc/steps/route-fresh-start.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`). It carries Step 1 (Read Project State) through Step 6 (Compose Pipeline and Begin) and the FAILURE MODES. A resume never loads it.
