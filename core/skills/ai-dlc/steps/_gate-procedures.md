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
   path | dispatched-at`) — the deliverable path is COPIED FROM THE BRIEF,
   which Rule 20 requires to name it, never invented here to fill the cell
   — and **DELETE** every row whose deliverable has
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

    scripts/wait-for-deliverable.sh [--since <epoch|ISO8601>] <path> [<path> ...]

- `exit 0` — beat complete. Read the output: consume the `DELIVERED <path>` lines,
  beat again over the `WAITING <path>` ones. Exit 0 alone does not mean all landed.
- `exit 1` — Rule 20 non-delivery. Re-dispatch, then HARD_BLOCK.

**A waiting beat exits 0 on purpose.** Waiting is what most beats report, and a
nonzero exit from a backgrounded command is reported to you as `status: failed` —
which would announce a failure every couple of minutes on every healthy join, and
bury the one exit code that does need a decision. Nonzero means non-delivery, nothing
else.

**Delivered means non-empty AND written since the join armed** — not merely present.
A deliverable path reused across sprints otherwise reports the PREVIOUS sprint's file
as delivered in under a second, and that is consumed as this sprint's input with
nothing downstream to catch it.

**`--since` is optional and only ever needed when the teammate may have delivered
BEFORE you armed the join** — normally only when resuming a join after a compaction.
Pass the `dispatched-at` value from the row (defined above). It can only move the
threshold earlier; a stamp later than now is clamped, so rounding it is harmless.

**Pass the whole wave to ONE call.** Never chain beats in a single `Bash` call.

**Never hand-roll the wait.** `until [ -s <path> ]; do sleep 15; done`,
`while [ ! -s <path> ]; ...`, and any bare `sleep` on a deliverable are **Rule 29
Check A violations**; gate Check 25 counts them. Do not poll a subagent's raw output
file under `/private/tmp/.../tasks/<agent-id>` — the deliverable path in the
snapshot's In-Flight Teammates row is the handle.

## Gate-adjudication dispatch (referenced by the gate)

When `gate-validation.md` says "dispatch the gate-adjudicator", execute this. It escalates
the read-and-compare (`adjudication: llm`) checks of ONE gate to a fresh Opus subagent so the
lead can run on a cheaper model without weakening the gate. The lead still owns PASS/FAIL: it
adopts the verdict only through Check 26.

**At gate entry, generate the nonce** — `<gate_type>-<UTC timestamp>`, e.g.
`implementation-20260715T140322Z` — and derive the verdict path:

    ${AI_DLC_STATE_DIR:-_bmad-output}/gate-adjudication/<gate_nonce>.verdict.json

The nonce makes a stale verdict live at a different path: the bounded-join cannot find a prior
gate's verdict, and Check 26 refuses one whose `gate_nonce` field is not this path's stem. That
closes the "absent verdict reads as pass" hole.

**Dispatch** ONE `gate-adjudicator`, `Agent` tool, `run_in_background: true` (Rule 29 — it must
not block the operator), bound to `.claude/team-roles/gate-adjudicator.md` per SKILL.md Rule 19
(both bindings: `model` and the standing role-contract Read line). Give it: the `gate_type`, the
`gate_nonce`, the verdict output path, and the artifact roots it may read. It derives its own
worklist with `scripts/validate-gate-adjudication.sh --expected <gate_type>` (the SAME derivation
Check 26 uses), reads each escalated check's body in `gate-validation.md` as the spec, and writes
one `GATE_ADJUDICATION_VERDICT v1` JSON to the verdict path. No Skill, no provenance block — it is
the native path with its own schema.

**Join** with the bounded-join beat (above): `scripts/wait-for-deliverable.sh <verdict_path>`.

**While it runs, the lead evaluates ONLY the `script` / `project` / `lead` checks.**
Inline-evaluating an `adjudication: llm` check is a Rule 20 solo violation — that judgment is the
adjudicator's, adopted at Check 26.

## Validation cycle (referenced by step files)

When a step file says "run the validation cycle", execute this — the Rule 8
convergence loop a planning step runs over its artifact. The step supplies the
PARAMETERS (party-mode seats + subject, adversarial focus, the `Seam D` label,
the artifact to changelog, and any source-fidelity check); everything here is the
same for every step, so it lives here and not restated in each step file.

**What the adversary and remediator DO is not restated in step files.** The
severity ladder, the verdict envelope, `EXIT_CONDITION_MET` /
`EXIT_CONDITION_NOT_MET` / `DIVERGENT_HARD_BLOCK`, the prior-scope discipline, and
the underived-claim bar all live in `team-roles/adversary.md` and
`team-roles/remediator.md`, and the gate enforces them mechanically
(`scripts/validate-adversarial-convergence.sh`, invoked by Check 24). A copy in a
step file is a copy that drifts.

**Join every spawn on its DELIVERABLE** — one `scripts/wait-for-deliverable.sh
<path> [<path> ...]` call per wave ("Bounded-join beat" above). A hand-rolled
`until`/`while`/`sleep` wait is a Rule 29 Check A violation that gate Check 25
counts.

**Intensity.** Run the minimum cycle SKILL.md Rule 8's intensity table names for
the declared `validation_intensity` — read that row; a copy here drifts. A
`lightweight` single pass is still a CONVERGENCE pass: it stamps a `verdict:` and
Check 24 reads it.

Execute the sub-skills back-to-back, with no pause for human input between them:

1. `/bmad-party-mode` — the step's seats (bound via the Rule 20 role-manifest
   preamble to their `.claude/team-roles/<role>.md`) walk the step's subject and
   apply every improvement; run the step's source-fidelity check if it names one.
   **Run sub-step snapshot update** ("Sub-step snapshot update" above), then
   proceed.
2. `/bmad-advanced-elicitation` — probe until zero ambiguity and update the
   artifact. **Run sub-step snapshot update**, then proceed.
3. **Adversarial convergence** — 2+ passes (a floor, not a target) through the
   **Adversarial review dispatch** and **Adversarial repair dispatch**
   sub-routines (below), carrying the step's declared focus. **Run sub-step
   snapshot update after each pass**, then **run auto-handoff evaluation**
   ("Auto-handoff evaluation" below) at `Seam D` with the step's label — FIRE
   ends the session, otherwise continue until the terminal pass stamps
   `EXIT_CONDITION_MET`. A `DIVERGENT_HARD_BLOCK` or STALL does not end the loop:
   follow "Divergence resolution dispatch" below.
4. Append the step's changelog, then proceed to the step's next action.

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
   operator_authorization: <ISO-8601 UTC ts of the operator's message> | "<verbatim substring, >=12 chars, copied from it>"
   archive: <dir>            # RESTART_CYCLE only
   ADVERSARIAL_RESOLUTION_END -->
   ```

   | kind | what it means | what the gate checks |
   |---|---|---|
   | `REVERT_REPAIR` | put the artifact back to a state an earlier pass reviewed | `artifact_sha_after` must equal some earlier pass's `artifact_sha` |
   | `CUT_SCOPE` | remove the contested scope | `artifact_bytes_after` **<** `artifact_bytes_before` |
   | `CHANGE_APPROACH` | a different approach, on the operator's authority | sha changed; `scope_delta` present |
   | `RESTART_CYCLE` | abandon the series and start over | as above, **plus** the passes MOVED to an existing `archive:` dir |

   **`operator_authorization` is a CITATION, required for ALL FOUR kinds, and verified.** A
   resolution CLEARS a HARD_BLOCK, and a hard block is operator-gated by design (only the
   operator may adjudicate). So the field is not free text — it is a *timestamp* plus a
   *verbatim substring* of the operator's own message, and Check 24 checks that substring
   against the harness-owned session transcript using the genuine-operator predicate (the same
   one Rule 29 uses). If no genuine operator message in the pause window contains those words,
   the gate FAILS: a lead-authored resolution is not an operator adjudication. Quote a real span
   of what the operator actually typed (≥12 chars) — not a paraphrase, and not a token. The
   machine notarizes that a human said it; you and the operator own what it means. (This closes
   the S290 hole: four "operator" dispositions authored in a window with zero operator messages.)

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

2. **Trigger basis (mode-dependent).** Exactly ONE of 2a / 2b applies:
   the one naming your `auto_handoff_mode`. Read that sub-item and stop.
   The other mode's rule does not apply to you, and reaching for it is
   the failure this split exists to prevent — these were a single
   paragraph until v0.73.0, and a `safe-seam` session read the
   `deploy-only` measured-red sentence out of it, found no red, and
   returned CONTINUE at three consecutive seams. Auto-handoff was
   silently disabled while the mode said it was on, which reads exactly
   like a mode with no seam reached.

   **2a. Under `safe-seam`** — the seam itself is the trigger. Only the
   token *magnitude* is advisory: how many tokens are in play does not
   gate the fire. The seam being reached IS the firing condition, so
   **skip the red check entirely** and proceed to precondition 3. There
   is no measured-red requirement in this mode; 2b does not apply.
   "Advisory magnitude" does NOT mean the handoff is optional — once a
   defined seam is reached and preconditions 3–7 pass, the fire is
   mandatory, not a judgment call about whether the context feels large
   enough.

   **2b. Under `deploy-only`** — require **measured red**: read
   `last_level` from `_bmad-output/.context-sensor-state` (authoritative
   and current every turn; fall back to `context_reminders_sent` in the
   snapshot Context Reminders block if the sidecar is absent). If it is
   not `red`, return CONTINUE. The sensor sets `red` only from a real
   measurement of resident context — Claude Code's own figure, read off
   the transcript — so this precondition is equivalent to "red threshold
   measured, not estimated". There is no estimate path: the sensor is
   silent when it cannot measure.

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
   record from Step 1. Commit the finalized snapshot if the project
   tracks `_bmad-output/`, then push the current branch to origin
   (`git push`) so the Step 2 commit and the finalized state reach the
   remote and are not stranded on this machine. If the push fails (no
   remote configured, offline, or a protected branch), note the reason
   in the auto-handoff line and continue; the local commits still stand
   and the handoff is not blocked.
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

The active thresholds are DERIVED by the sensor from the resolved
effective window — each band is a clamped percentage of the window, a
bounded lead below the ceiling (`effectiveWindow - 31,000`), not read
from a table. At a 200K window that lands at yellow 80K / red 120K; at
larger windows the bands scale with the ceiling, clamped. The sensor
records the level it fired in `_bmad-output/.context-sensor-state`.

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
