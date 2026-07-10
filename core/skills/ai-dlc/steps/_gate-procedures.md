---
name: _gate-procedures
description: Procedures invoked by reference from pipeline step files (sub-step snapshot update, auto-handoff evaluation) — extracted from gate-validation.md so their bodies stay out of the resident gate path and load only at their invocation seam
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
3. Do NOT refresh other sections (Pipeline Position, Sprint Context,
   Locked Decisions remain gate-scope). Do NOT re-evaluate context
   reminder thresholds here — reminder evaluation stays at gate
   boundaries per `gate-validation.md` Check 14.

This keeps mid-step compaction survivable: the snapshot's Recent
Activity reflects the in-flight sub-step rather than only the last
gate. The full Check 14 still runs at the next gate.

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
updates the Context Reminders fields defined in Check 14's six-section
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
