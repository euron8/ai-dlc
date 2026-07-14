---
name: _gate-procedures
description: Procedures invoked by reference from pipeline step files (sub-step snapshot update, bounded-join beat, auto-handoff evaluation) — extracted from gate-validation.md so their bodies stay out of the resident gate path and load only at their invocation seam
---
<!-- STEP_LOADED_TOKEN: gate-procedures -->

# Gate Procedures (invoked by reference)

These procedures are invoked **by name** from pipeline step files — they are
NOT gate checks and are NOT part of the `gate-validation.md` Check 1–H2
sequence. They were extracted from `gate-validation.md` (v0.24.0 Phase 1) so
their bodies do not sit resident on every gate; a step file loads this file
`READ AND FOLLOW`-style when it says "run sub-step snapshot update" or "run
auto-handoff evaluation at Seam <X>". `gate-validation.md` retains a one-line
forwarding pointer at each former location.

## Sub-step snapshot update (referenced by step files)

Step files invoke this lightweight update after each validation
sub-skill and after each story transition during implementation.
Gate passages still run the full Check 14 in `gate-validation.md`;
sub-step updates are narrower in scope.

When a step file says "run sub-step snapshot update", execute:

1. Append a one-line entry to **Recent Activity** naming the
   sub-skill completed or transition observed, with timestamp and
   artifact touched (e.g., `2026-04-17T15:22Z — /bmad-party-mode
   completed on PRD — _bmad-output/planning-artifacts/prd.md`).
2. Refresh **Open Items** from current state of
   `docs/escalations/pending.md` and any open triage items.
3. Reconcile **In-Flight Teammates**: add a row for every teammate
   dispatched since the last update (`agent name | role | deliverable
   path | dispatched-at`), and **DELETE** every row whose deliverable has
   been consumed. Rows only — no prose, no struck-through history. A
   consumed teammate is not in flight. This section must be written **at
   dispatch**, not only at the transition that follows it — a teammate
   dispatched and compacted-over before its row is written is exactly the
   teammate the lead will re-dispatch blind.
4. Do NOT refresh other sections (Pipeline Position, Sprint Context,
   Locked Decisions remain gate-scope). Do NOT re-evaluate context
   reminder thresholds here — reminder evaluation stays at gate
   boundaries per `gate-validation.md` Check 14.
5. Run the snapshot budget check:

       scripts/verdict.sh validate-artifact-budget --only pipeline-snapshot.md

   The script reports an overage inside the grace band (a `warn` line,
   exit 0) and breaches only past it.

   - `warn` (over budget, within grace) → note it and continue.
   - **Exit 1 (past the grace band) → TRIM NOW, before the next
     sub-step.** Move superseded narrative verbatim to
     `pipeline-snapshot-history.md` (write-only), re-run, then continue.

   Do NOT defer the trim to a later pause. The gate (Check 14) remains
   the blocking point.

   Call it through `verdict.sh`, which prints one line and **exits with
   the validator's own status**. Do NOT hand-roll
   `validate-… | grep -E 'OVER|PASS'`: a pipe hands the exit status to
   `grep`, so a validator that prints FAIL and exits 1 reads as a pass.

This keeps mid-step compaction survivable: the snapshot's Recent
Activity reflects the in-flight sub-step rather than only the last
gate, and In-Flight Teammates carries the deliverable paths that let
the lead re-join its teammates instead of re-dispatching them.

The budget is checked here, not only at gates. The full Check 14 still
runs at the next gate.

## Bounded-join beat (referenced by step files)

When a step file says "join the deliverable", execute this. It is Rule 29's
bounded file-wait beat, and it is the ONLY sanctioned way to wait for a teammate.

**The handle.** An `Agent` spawn returns an `agent_id`. `TaskOutput` joins a
`task_id`, which only `TaskCreate` produces — **`TaskOutput` cannot join an `Agent`**,
and a `Skill` spawn returns no handle at all. Every ai-dlc teammate delivers by file
(Rule 20): **the deliverable file IS the handle.**

**The call.** One `Bash` call, every path in the wave:

    scripts/wait-for-deliverable.sh <path> [<path> ...]

- `exit 0` — all delivered. Consume them.
- `exit 2` — not yet. Beat again (the script bounds the sequence).
- `exit 1` — Rule 20 non-delivery. Re-dispatch, then HARD_BLOCK.

**Pass the whole wave to ONE call.** Never chain beats in a single `Bash` call.

**Never hand-roll the wait.** `until [ -s <path> ]; do sleep 15; done`,
`while [ ! -s <path> ]; ...`, and any bare `sleep` on a deliverable are **Rule 29
Check A violations**; gate Check 25 counts them. Do not poll a subagent's raw output
file under `/private/tmp/.../tasks/<agent-id>` — the deliverable path in the
snapshot's In-Flight Teammates row is the handle.

## Adversarial review dispatch (referenced by step files)

When a step file says "run an adversarial review pass", execute this. It is the REVIEW half of
the Rule 8 cycle; the repair half is below.

**No Skill runs.** The convergence review is ai-dlc-native: the method is `team-roles/adversary.md`,
in full. The bmad skill `/bmad-review-adversarial-general` is NOT invoked here — its contract
(*find at least ten issues; HALT if zero findings; emit no severity, priority, or ranking*) has
no fixed point in a loop whose exit condition is zero CRITICAL and zero MAJOR, and it forbids the
severity fields Check 24 reads. It remains correct for a ONE-SHOT cynical sweep, and the step
files that run one still invoke it.

**Dispatch** ONE `adversary` per pass. Agent tool, bound to `.claude/team-roles/adversary.md` per
SKILL.md Rule 19 (both bindings: `model` and the standing role-contract Read line). Give it: the
artifact path under review, the canonical output path, the pass number, and — on pass 2+ — the
PRIOR pass's findings and the repair record, because pass 2+ reviews the REPAIR, not the document
again.

It writes findings to `_bmad-output/planning-artifacts/s<N>-<artifact>-adversarial-p<M>.md`
carrying a `SKILL_INVOCATION_PROVENANCE v1` block with `skill: ai-dlc-adversary-review`,
`mode: subagent`, the `tool_use_id` of THIS Agent dispatch, `artifact` + `artifact_sha`, the four
`findings_*` counts, and the `verdict:`. Filename numbering is load-bearing: Check 24 orders the
series by the `p<M>` token.

**Join** with the bounded-join beat (above): `scripts/wait-for-deliverable.sh <findings_path>`.

**Zero findings on a later pass is the EXPECTED outcome, not a suspicious one.** The cycle exists
to reach it. An adversary that manufactures a finding to justify its pass sends the remediator to
edit a correct artifact, and the edit is where new defects come from.

## Divergence resolution dispatch (referenced by step files)

When the cycle **STOPS** — a pass stamps `DIVERGENT_HARD_BLOCK`, or Check E fires a STALL — the
Rule 8 cycle does not end. It waits. Execute this, in this order. You cannot skip a step: the
PreToolUse hook denies every `Agent` / `Skill` / `Task` dispatch until step 3 has produced a file.

**STOP → ADJUDICATE → RESOLVE → VERIFY**

1. **STOP.** No further pass on the artifact as it stands. Do not dispatch a remediator: a repair
   on unchanged scope is what diverged, and running one now is the failure repeating.
2. **ADJUDICATE.** Escalate to the operator (Rule 11(a)). Present the finding, the repair that
   caused it, whether that repair weakened something LOAD-BEARING (an AC, a predicate, a guard, a
   `LOCKED_REQUIREMENTS` entry — test: *after the edit, can the check still FAIL?*), and your
   recommended resolution KIND. **The operator picks the kind.**
3. **RESOLVE.** *A repair edits the artifact to close findings on UNCHANGED scope. A resolution
   changes WHAT IS UNDER REVIEW.* The LEAD writes the record — not the adversary (it would only be
   echoing the lead's claim) and not the remediator (it authors repairs, which is the thing being
   stopped). Write it to `_bmad-output/planning-artifacts/s<N>-<artifact>-resolution-p<M>.md`
   (`<M>` = the pass being resolved). **This write is permitted while paused**; it is the one write
   the pause is waiting for.

   ```
   <!-- ADVERSARIAL_RESOLUTION v1
   resolves: <path of the DIVERGENT_HARD_BLOCK pass>
   resolution: REVERT_REPAIR | CHANGE_APPROACH | CUT_SCOPE | RESTART_CYCLE
   adjudicated_by: operator
   artifact: <path of the artifact under review>
   artifact_sha_before: <MUST equal the resolved pass's artifact_sha>
   artifact_sha_after:  <sha256 after the resolution>
   artifact_bytes_before / artifact_bytes_after: <int>
   scope_delta: <what changed, concretely>
   locked_requirements_touched: <none | entries + the operator's authorization>
   operator_authorization: <the operator's own words, verbatim>
   archive: <dir>            # RESTART_CYCLE only
   ADVERSARIAL_RESOLUTION_END -->
   ```

   | kind | what it means | what the gate checks |
   |---|---|---|
   | `REVERT_REPAIR` | put the artifact back to a state an earlier pass reviewed | `artifact_sha_after` must equal some earlier pass's `artifact_sha` |
   | `CUT_SCOPE` | remove the contested scope | `artifact_bytes_after` **<** `artifact_bytes_before` |
   | `CHANGE_APPROACH` | a different approach, on the operator's authority | sha changed; `scope_delta` + `operator_authorization` present |
   | `RESTART_CYCLE` | abandon the series and start over | as above, **plus** the passes MOVED to an existing `archive:` dir |

   **FREEZE is not on this list and is rejected by name.** A hard block means CRITICALs rose in
   text a previous pass had already reviewed — text that is *already frozen*. Freezing it again
   removes nothing: the verification pass reads the same bytes and finds the same CRITICALs. There
   is no wording of a freeze that passes Check 24. (Freezing IS the remedy for a *moving artifact*
   — a cycle that cannot converge because the sprint grows under it. Opposite failure, opposite
   remedy. Conflating the two parked a live pipeline for a day.)

   **`RESTART_CYCLE` must MOVE the abandoned passes**, not leave them. A restart writes p1, p2, p3
   over the dead cycle's files — and if the dead cycle ran to p17, then p4…p17 are still on disk,
   the glob chains them onto the new series, and the gate adjudicates the corpse. `git mv` them to
   `planning-artifacts/archive/<series>-cycle-<n>/`. Do not delete them; retro reads them.

4. **VERIFY.** Dispatch **ONE** adversary (procedure above) against the RESOLVED artifact, as the
   **next pass number in the SAME series**, declaring `resolves_divergence: <the record>`. Do not
   open a new series: `--series` spans both, the pass numbers collide, and the gate then fails on
   a cycle that did nothing wrong. That pass is the terminal clean pass Check 24 requires.

## Adversarial repair dispatch (referenced by step files)

When a step file says "repair the findings", execute this. **The lead does not repair the
artifact itself** — it is the most context-saturated agent in the pipeline and repairs from a
compacted summary, not the document. (Rationale + the measurement: notes R35.)

**Dispatch** ONE `remediator` per adversarial pass — never per finding; the artifact is one
document and parallel editors contradict each other. Agent tool, bound to
`.claude/team-roles/remediator.md` per SKILL.md Rule 19 (both bindings: `model` and the
standing role-contract Read line). It takes that pass's WHOLE finding set.

It writes the repaired artifact in place plus a **repair record** at
`_bmad-output/planning-artifacts/s<N>-<artifact>-repair-p<M>.md` (`<M>` = the pass repaired):
per finding, the disposition, the edit site, and the command that derives every factual claim
the repair asserts, with its output. The next adversarial pass verifies against that record.

**Join** with the bounded-join beat (above): `scripts/wait-for-deliverable.sh <repair_record_path>`.

**The lead keeps** dispatch, the join, and the **Rule 11/13 scope calls** the remediator
escalates (cut-versus-fix, `LOCKED_REQUIREMENTS`, anything changing what the sprint delivers).
Those are decisions, not edits.

## Auto-handoff evaluation (referenced by step files)

Step files invoke this helper at each safe seam defined in SKILL.md
Handoff Protocol "Auto-handoff (configurable via `auto_handoff_mode`)".
When a step file says "run auto-handoff
evaluation at Seam <X>", execute this procedure. The outcome is
either CONTINUE (no-op — the step resumes normally) or FIRE (the
lead executes the Rule 2(a) handoff and the session ENDS). This
helper MUST NOT be invoked from inside the `gate-validation.md`
Check 1–15 sequence; it is only called from step files at the defined seams.

Every defined safe seam is a clean step/sub-step boundary. Auto-handoff
MUST fire only at such a boundary; it MUST NOT fire mid-sub-step.
Auto-handoff is NOT a fourth Rule 3 pause point — it is a
session-terminating action that executes the path (a) procedure
(`steps/handoff.md`) unchanged.

**Inputs:** the seam name (`Seam A` through `Seam E`; `Seam E` is the
retro-entry seam at `retro.md` Step 1 pre-flight, before party mode) and
a short human-readable
label for the distinguishing
output line (e.g., `deploy-validate Step 0 pre-flight`,
`implementation story transition`,
`architecture adversarial pass 2`).

**Evaluate preconditions in this order. The first failing
precondition returns CONTINUE immediately — no fire, no side
effects, the step resumes.**

1. **Mode gate.** Read `auto_handoff_mode` from SKILL.md Handoff
   Protocol "Auto-handoff" section. If `off`, return CONTINUE. If
   `deploy-only` and the seam is not `Seam A`, return CONTINUE. If
   `safe-seam`, all defined seams (`Seam A` through `Seam E`) are
   permitted. Proceed to precondition 2.

2. **Trigger basis (mode-dependent).** Under `safe-seam`, the seam
   itself is the trigger. Only the token *magnitude* is advisory — how
   many tokens are in play does not gate the fire. The seam being
   reached is the firing condition: skip the red check and proceed to
   precondition 3. "Advisory magnitude" does NOT mean the handoff is
   optional — once a defined seam is reached and preconditions 3–7
   pass, the fire is mandatory, not a judgment call about whether the
   context feels large enough. Under
   `deploy-only`, require **measured red**: read `last_level` from
   `_bmad-output/.context-sensor-state` (authoritative and current
   every turn; fall back to `context_reminders_sent` in the snapshot
   Context Reminders block if the sidecar is absent). If it is not
   `red`, return CONTINUE. The sensor sets `red` only from a real
   measurement of resident context — Claude Code's own figure, read
   off the transcript — so this precondition is equivalent to "red
   threshold measured, not estimated". There is no estimate path: the
   sensor is silent when it cannot measure.

3. **Snapshot is current.** Read the most recent Recent Activity
   entry. If it does not reflect either (a) the gate passage that
   most recently ran Check 15, or (b) the sub-step snapshot update
   preceding this seam, run the sub-step snapshot update now and
   re-read. If the update fails or Recent Activity still does not
   reflect the preceding sub-step, return CONTINUE — firing
   auto-handoff on a stale snapshot would produce a broken resume
   contract.

4. **No gate validation currently executing.** This precondition is
   satisfied by-construction: step files MUST NOT invoke this
   helper from inside the Check 1–15 sequence. If the caller is
   inside Check 1–15, return CONTINUE — treat as a caller bug.

5. **No deployment currently executing.** This precondition is
   satisfied by-construction: Seam A runs at `deploy-validate.md`
   Step 0, before Step 1. No other seam runs during
   `deploy-validate.md` Steps 1–5. If the caller is between Step 1
   and Step 5, return CONTINUE.

6. **No teammate awaiting lead orchestration response.** Check the
   task list for in-progress tasks that are blocked on a lead
   mediation or response. Inspect recent teammate messages
   awaiting the lead. If any teammate is awaiting a response,
   return CONTINUE — firing handoff while a teammate is blocked
   would strand the teammate.

7. **Not at any Rule 3 pause point.** Verify the lead is not
   currently in ambiguity resolution, the Production Validation
   Checkpoint, the retro commentary prompt, or the post-compact
   verification turn. If any pause point is active, return
   CONTINUE.

**These seven preconditions are EXHAUSTIVE — there is no eighth.**
User activity, user presence, the recency of a user message, or the
absence of an explicit stop request is NOT a precondition and MUST NOT
be treated as permission to return CONTINUE. Specifically, "the user
has been active this session but did not share `/context`, so I may
continue unless they intervene" is a PROHIBITED rationalization: it
invents a precondition that does not exist and inverts the contract
(the fire is the default at a passed seam, not something the user must
opt into). The token magnitude being advisory (precondition 2) governs
only *how large* the context is — it never converts the fire itself
into a discretionary call. If all seven preconditions pass, the outcome
is FIRE; the lead does not get to weigh whether a handoff "feels"
warranted. This applies identically under `safe-seam` and `deploy-only`
(under `deploy-only`, precondition 2's Mode-1 red requirement is itself
one of the seven — once it and the rest pass, the same
no-rationalization rule holds).

If all seven preconditions pass, FIRE auto-handoff. This is the
Rule 2(a) handoff procedure (canonical base in `steps/handoff.md`),
repeated here as the auto-handoff variant — the distinguishing output
line in step 4 identifies this handoff as automated, and steps 3/5
carry the no-human-present additions:

1. **Stop all in-flight teammates first.** Call `TaskStop` on
   every `in_progress` task. Halt any Agent-spawned teammate not
   bound to a task. Wait until every teammate has returned before
   proceeding. Record stopped teammates and in-flight artifacts in
   the snapshot's Open Items in Step 3.
2. `git add` and `git commit` any in-flight work, including work
   teammates left in the working tree.
3. Finalize the pipeline snapshot — one last update capturing
   in-flight state, current sub-step, and the stopped-teammate
   record from Step 1.
4. Output the distinguishing auto-handoff line (substitute mode,
   seam label, and trigger basis), then output the resume prompt
   (SKILL.md Handoff Protocol template) wrapped in `----` delimiter
   lines. The trigger basis depends on mode: under `safe-seam` it is
   `seam trigger (token threshold advisory)`; under `deploy-only` it is
   the confirmed token count from the most recent user-shared `/context`:

   > *"Auto-handoff triggered by auto_handoff_mode=safe-seam at Seam E
   > (seam trigger, token threshold advisory)."*

   > *"Auto-handoff triggered by auto_handoff_mode=deploy-only at
   > Seam A. Context at <tokens> tokens, red threshold confirmed via
   > user-shared /context."*

   The resume line is the bare `/ai-dlc resume` (the successor reads the
   snapshot for all state). If auto-session-chaining is in use, also
   `touch _bmad-output/.driver/handoff` — the driver's zero-content
   handoff signal.

5. Create the pause flag so the continuation hook allows this
   auto-handoff to end the session (an autonomous handoff has no user
   message to set it): `touch _bmad-output/pipeline-paused.flag`. Then
   end the session — do not continue the pipeline in this conversation.
   Reply to any further messages with a pointer to the snapshot and the
   resume prompt. Resume itself is NOT automated: the user MUST open a
   new conversation and paste the resume prompt.

A FIRE outcome does not return control to the calling step. A
CONTINUE outcome returns silently — the step proceeds with its
next directive (typically the `gate-validation.md` call, the next
adversarial pass, or the next story transition orchestration).

## Context reminder threshold check (referenced by Check 14)

Invoked by `gate-validation.md` Check 14 at every gate. It reads and
updates the Context Reminders fields defined in Check 14's seven-section
snapshot schema (which stays resident); the evaluation mechanics below do
not.

**Context reminder threshold check (required at every gate):**

Read the Context Reminders block from the snapshot. If any required
field is absent (e.g., snapshot predates this rule), initialize
missing fields before proceeding: `context_reminders_sent: none`
and each `last_*_fire_tokens`/`last_*_fire_turns` to `null`.

The active thresholds live in the SKILL.md Handoff Protocol
"Threshold defaults" table, which the sensor hook parses directly:
- 200K model context → yellow 80K tokens, red 120K tokens
- 1M model context  → yellow 120K tokens, red 200K tokens

The lead does not measure or estimate its own context window. The
`ai-dlc-context-sensor.sh` hook measures it every turn (Stop) and every tool batch (PostToolBatch) from the
session transcript, fires the Rule 2(b)/(c) reminder, and owns both
the dedupe and the recurrence arithmetic (50,000-token / 20-turn
delta). This gate check therefore **reads** the result; it does not
compute one.

Read `_bmad-output/.context-sensor-state`. It is a flat key=value
file:

```
last_level=none|yellow|red
last_fire_tokens=<int>
last_fire_turn=<int>
turn_counter=<int>
last_measured=<int>
model_row=200K|1M
row_known=0|1
effective_window=<int>
```

Reconcile the snapshot's Context Reminders fields to it:

- `context_reminders_sent` := `last_level`
- `last_yellow_fire_tokens` / `last_yellow_fire_turns` := the
  sidecar's `last_fire_tokens` / `last_fire_turn` when `last_level`
  is `yellow`
- `last_red_fire_tokens` / `last_red_fire_turns` := likewise when
  `last_level` is `red`

If the sidecar is absent, the sensor has not fired this pipeline (a
fresh session, or context still below yellow). Leave the snapshot
fields at `none` / `null`. Do **not** substitute an estimate: a guess
beside an authoritative number is worse than silence.

If `row_known=0`, the sensor is assuming the 200K threshold row
because the model's context-window size is not recorded anywhere in
the transcript. Reminders may therefore fire early on a 1M model.
Setting `AI_DLC_MODEL_ROW` to `200K` or `1M` in the project's
`.claude/settings.json` `env` block removes the ambiguity; the sensor
also self-corrects once it observes a reading no 200K model could
reach.

Do **not** re-emit the reminder here. The hook already delivered it
to the lead as `additionalContext` on the turn it fired. A user reply
to a reminder is a Rule 11 directive handled on the next turn.

User-shared `/context` output remains valid as manual confirmation. If
the user shares it and it disagrees materially with `last_measured`,
trust the user, say so, and note the discrepancy in the retro — the
sensor reads Claude Code's own figure, so a real disagreement means
the sensor is broken.
