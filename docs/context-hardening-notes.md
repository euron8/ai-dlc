# Context Hardening Notes

**Date:** 2026-04-17
**Scope:** Summary of the 12-requirement change set applied to
AI/DLC context management and post-compact recovery.

This document is the honest contract between the design and the
user. If you are maintaining or extending the context-management
rules, read this first.

---

## What changed

Twelve requirements (R1–R12 from the design spec) were applied
across eleven files — five with substantive rewrites and six
validation-cycle step files that gained sub-step snapshot update
directives.

**Substantive rewrites (5):**

- `core/skills/ai-dlc/SKILL.md` (Rule 7 pause points, Rule 10
  handoff + snapshot + thresholds)
- `core/skills/ai-dlc/steps/gate-validation.md` (Check 14 rewrite,
  new Check 15, sub-step snapshot update helper)
- `core/skills/ai-dlc/steps/route.md` (Step 0a integrity validation)
- `core/skills/ai-dlc/steps/deploy-validate.md` (Step 0 pre-flight
  context check)
- `templates/CLAUDE.md.template` (Post-Compact Recovery Protocol,
  token-threshold Session Model)

**Sub-step snapshot update directives (6):** `discovery.md`,
`research-requirements.md`, `architecture.md`,
`stories-test-strategy.md`, `sprint-review-next.md`,
`implementation.md`.

### R1 — Model-aware absolute token thresholds

Replaced 40%/50% percentage thresholds with absolute token counts.
Defaults:

| Model context | Yellow (first reminder) | Red (urgent) |
|---|---|---|
| 200K | 80K tokens | 120K tokens |
| 1M   | 120K tokens | 200K tokens |

Projects override via `{context_thresholds}` populated by
`/ai-dlc-setup`. Research-observed degradation is tied to absolute
tokens, not fraction-of-window; percentages produce nonsensical
thresholds across different models.

### R2 — Post-Compact Recovery Protocol in CLAUDE.md

Placed in CLAUDE.md (not only in the skill) so it survives
`/compact`. First post-compact action: read the snapshot in full,
then output an acknowledgment line naming current step file and
last gate.

**Auto-compact ordering invariant (moved from SKILL.md L506–523,
2026-07-10).** The red reminder must fire before Claude Code's
auto-compact threshold, bounded on both sides:
`red + MIN_SLACK < threshold < red + MAX_DRIFT` (defaults 50,000 /
100,000). The lower bound exists because compaction is strictly
lower-fidelity than the handoff: `/clear` + `/ai-dlc resume` rehydrates
from a schema'd, gate-verified snapshot, while compaction keeps a lossy
summary of unknown content. Red must fire first so the handoff gets
first refusal. A threshold near the resident prefix is worse still —
every post-compact turn refills immediately, and three such refills trip
Claude Code's rapid-refill breaker, which terminates the session. The
upper bound bounds the damage when red is ignored (an unattended run, or
`auto_handoff_mode: off`). On a 1M model the default threshold is
987,000, some 787,000 tokens past red — long enough to complete a sprint
entirely inside a degraded context; setting `autoCompactWindow` to
300,000 moves the net to 287,000. AI/DLC does not write this value: the
safe floor also depends on the project's fixed prefix, which the skill
cannot measure. The same rationale is carried verbatim in
`core/scripts/validate-compact-window.sh` (header) and enforced by it.

### R3 — Post-compact verification turn

Immediately after the acknowledgment, the lead outputs current step
file, last gate + timestamp, any in-flight sub-step, current git
branch and last commit. Then pauses with:
*"Does this match your last state? Reply `proceed`, `correct
<what>`, or `handoff`."* This is a mandatory pause point — the
fourth one in SKILL.md Rule 7.

### R4 — Differentiated reminder text

Yellow and red reminders no longer present three equivalent options.
Yellow: handoff (recommended before any gate or deployment),
`/compact` (mid-step only), continue (sub-step wrapping soon).
Red: handoff at next sub-step boundary, avoid `/compact` before any
gate, deployment, or adversarial review.

### R5 — Sub-step snapshot updates

Gate passages still trigger the full Check 14 refresh. Sub-step
boundaries (each party-mode / elicitation / adversarial-pass
completion; each story transition ready-for-dev → in-progress →
review → done) trigger a lightweight refresh of Recent Activity and
Open Items only. Mid-step compaction no longer drops in-flight
state.

### R6 — Gate-validation Check 15

Check 14 asserts "update the snapshot". Check 15 verifies the
assertion took effect: re-reads the snapshot and confirms the
last-gate name, timestamp, current_step_file, and any advanced
reminder state all match. Gate FAILS on mismatch; double failure
is a HARD_BLOCK (snapshot writer broken).

### R7 — Snapshot integrity validation on resume

`route.md` Step 0a runs before dispatch on any resume. Four
integrity checks: (1) all six required sections present, (2)
`current_step_file` exists on disk, (3) git branch matches the
snapshot's recorded branch, (4) `last_gate_passed` is within 7
days (warn otherwise). Failures surface with specific remediation
options — resume never silently proceeds on corrupted or stale
snapshots.

### R8 — Recurring reminders

Both yellow and red reminders fire on first crossing, then re-fire
every additional 50K tokens OR every 20 turns past the last fire,
whichever comes first. Long sessions are no longer served by a
single early alert. Check 14 tracks fire state in
`last_yellow_fire_tokens/turns` and `last_red_fire_tokens/turns`.

### R9 — User is source of truth for context introspection

The lead cannot reliably self-measure its own context window.
User-shared `/context` output is the authoritative trigger. The
lead may invite the user to share `/context` at any point; when
none is available, the lead falls back to a conservative
turn-and-tool-output estimate that errs high.

### R10 — Pre-deployment fresh-session hard rule

`deploy-validate.md` Step 0 runs before any deployment step. The
lead MUST confirm context is below the yellow threshold via either
user-shared `/context` or a handoff to a fresh session. Deploying
from a degraded session is not permitted. Hard gate, no bypass.

### R11 — Fixed Rule 10 contradiction

Reminders are non-blocking OUTPUT: the line is printed, the next
action proceeds. User replies to reminders are Rule 4 directives
and the user's judgment is authoritative. "Non-blocking output"
and "user authority" are no longer in conflict.

### R12 — Research citations footnote

SKILL.md Rule 10 ends with citations for the threshold choices
(Chroma Hong et al. 2025 context-rot; Claude Code empirical
degradation ~147K tokens in 200K window; Anthropic context
engineering guidance). Future maintainers can re-check thresholds
against primary sources before changing them.

---

## What is now guaranteed (to the extent Claude Code's documented behavior holds)

- **Post-compact recovery directive is visible.** CLAUDE.md is
  preserved through compaction, so the recovery protocol is in the
  lead's context even after history is summarized.
- **First post-compact output forces a snapshot re-read.** The
  acknowledgment line cannot be written without reading the
  snapshot first (it must name the current step file and last
  gate, which live only in the snapshot).
- **Verification turn surfaces summary drift before action.** The
  lead must enumerate current step, last gate, in-flight sub-step,
  and branch + commit. The user sees these before any pipeline
  action resumes and can correct.
- **Integrity checks on resume catch corrupted or stale snapshots.**
  Step 0a fails loudly rather than dispatching on a bad state.
- **Thresholds match research.** Token-based, model-aware, cited.
- **Degraded deployment is blocked.** Deploy-validate Step 0 won't
  proceed without a fresh-session confirmation.
- **Check 15 catches silent snapshot-write failures.** An
  un-updated snapshot fails the gate rather than passing
  unnoticed.

## What remains outside the system's control

- **Compact summary fidelity.** The model-generated compact summary
  is lossy. Specific facts the snapshot relies on might be dropped
  from conversation history. Mitigation: snapshot is source of
  truth, not scrollback; verification turn exposes drift.
- ~~**Self-introspection precision.**~~ *Resolved by R28 (v0.36.0).*
  The lead still cannot count its own tokens, but it no longer needs
  to: the `ai-dlc-context-sensor.sh` Stop hook reads the figure off
  the transcript each turn. What remains outside the system's control
  is the model's **context-window size**, which Claude Code records
  nowhere in the transcript; the sensor infers it, and
  `AI_DLC_MODEL_ROW` pins it.
- **Claude Code behavior changes.** This design assumes CLAUDE.md
  is preserved through `/compact`. If Claude Code changes that
  behavior in a future release, the Post-Compact Recovery Protocol
  stops being reliably visible to the lead. **This is a dependency
  to re-verify on every Claude Code update.** Watch the CHANGELOG
  and release notes for changes to compaction, CLAUDE.md loading,
  or system-reminder injection.
- **User discipline.** If the user ignores reminders and never
  shares `/context`, the system degrades gracefully but cannot
  prevent the user from running a 300K-token session on a 200K
  model.

## Dependency re-verification checklist

Run this list when Claude Code updates:

1. Does Claude Code still preserve CLAUDE.md through `/compact`?
   Test by compacting a long session and confirming CLAUDE.md
   content is still in the lead's context.
2. Does auto-compact fire at a predictable token count, or has the
   threshold changed? If changed, revisit R1 defaults.
3. Does `/context` still report usable token counts that align
   with actual window usage?
4. Are system-reminders still injected per-turn? Rule 10's
   reminder-line semantics depend on the lead outputting text
   each turn.

## Historical context

The 2026-04-16 compliance review (`docs/analysis/compliance-review.md`)
identified weaknesses in the prior 40%/50% rule. This change set is
the response. Future retros should cite `context-hardening-notes.md`
(this file) rather than re-deriving the design from the code.

---

## 2026-04-17 Follow-up (R13–R19)

The R1–R12 change set landed the runtime contract but left six
adjacent surfaces out of sync: the `/ai-dlc-setup` wizard,
`QUICKSTART.md.template`, a loose spec in R9's fallback, and two
unresolved compliance-review findings. Seven follow-up
requirements (R13–R19) closed those gaps. All are deterministic
file edits; completion is verifiable by grep.

### R13 — Wire `{context_thresholds}` into `/ai-dlc-setup`

Step 2 of the setup wizard now has a "Populate context thresholds"
sub-step that derives the active lead model's context window (200K
or 1M) from the confirmed model strings, offers the Rule 10
defaults with a custom-override option, and substitutes the
threshold block into `CLAUDE.md`. `CLAUDE.md.template` was
restructured so `{context_thresholds}` is a clean standalone
placeholder (the earlier two-row reference table was moved into
an HTML comment). A fresh install now passes Step 9 validation
without manual cleanup.

### R14 — QUICKSTART four pause points

`QUICKSTART.md.template` "Key design principles" updated from
"Two pause points" to the four points in SKILL.md Rule 7:
ambiguity resolution, Production Validation Checkpoint, retro
commentary prompt, and post-compact verification turn.

### R15 — QUICKSTART pipeline interruption gotcha

Replaced "re-invoke `/ai-dlc` and describe where you left off"
with the Rule 10 resume prompt pointing at
`_bmad-output/pipeline-snapshot.md`. The old text triggered the
exact failure mode `route.md` Step 0 is designed to prevent
(plain-description re-invocation archives the existing snapshot
and restarts from scratch).

### R16 — QUICKSTART Context Window Guide rewritten

Full rewrite covering (in order): pipeline snapshot as primary
state vehicle, disk artifacts secondary, context thresholds
populated via `{context_thresholds}`, recurring reminders
(50K-token / 20-turn delta), user-is-source-of-truth with Mode 2
fallback reference, formal Rule 10(a) handoff procedure, and
post-compact recovery. Teammate-context-isolation retained;
obsolete "describe where you left off" advice removed entirely.

### R17 — Fallback estimator two-mode spec

Both `templates/CLAUDE.md.template` Session Model and
`gate-validation.md` Check 14 now specify two explicit modes.
**Mode 1** (user-shared `/context`, authoritative) drives
threshold evaluation and recurrence arithmetic; fires the full
Rule 10 reminder and advances fire state. **Mode 2** (fallback
estimate, advisory only) uses a deterministic formula —
`15,000 + turns*2,000 + tool_output_bytes*0.25` — and emits a
lighter check-line asking the user to share `/context`. Mode 2
does NOT advance `last_*_fire_tokens` / `last_*_fire_turns`, so
unverified estimates cannot re-fire noisily. Two identical leads
in the same state now produce the same Mode 2 estimate, which
restores the stability R8's 50K-token recurrence needs.

> **Superseded by R28 (v0.36.0).** Both modes are replaced by a
> direct measurement. Mode 2 is deleted outright; its estimator was
> wrong in both terms (baseline 15,000 against a measured resident
> floor of ~69,000; rate 2,000/turn against a measured ~1,200/turn),
> and it was silent at the true yellow crossing in 108 of 219 real
> sessions while overestimating by 69% at the median.

### R18 — `implementation.md` model placeholders

Applied Option B: Step 2 prose now reads "Spawn using the model
defined in the teammate's role file (`.claude/team-roles/<role>.md`).
The role file's `/model` directive is the authoritative model
binding." The three template variables (`{dev_model}`,
`{reviewer_model}`, `{qa_model}`) were removed from the step and
from `/ai-dlc-setup` Step 2's file-replacement list.

### R19 — `codebase-inventory.md` Step 4

Step 4 now says "Check 1 (validation cycle complete) is waived
for this analysis step — there is no planning artifact to
validate. All other applicable checks run normally, including
Check 14 (snapshot update) and Check 15 (snapshot verification)."
This delegates scoping to `gate-validation.md` rather than
overriding the protocol from the step file, which was silently
bypassing Check 14 and Check 15 on brownfield-a resumes.

### Compliance-review findings now resolved

The 2026-04-16 review (`docs/analysis/compliance-review.md`)
produced eight findings. After the R13–R19 follow-up, status:

- **FIND-1** (QUICKSTART "Two pause points" should be three) —
  **RESOLVED** by R14 (now correctly lists four).
- **FIND-2** (QUICKSTART pipeline-interruption gotcha bypasses
  snapshot resume) — **RESOLVED** by R15.
- **FIND-3** (QUICKSTART Context Window Guide predates Rule 10) —
  **RESOLVED** by R16.
- **FIND-4** (CLAUDE.md.template "13 checks" off by one) —
  **RESOLVED earlier** in the R6 commit (Check 15 addition
  updated the count to 15/15).
- **FIND-5** (`implementation.md` model placeholders) —
  **RESOLVED** by R18.
- **FIND-6** (`codebase-inventory.md` informal gate waiver) —
  **RESOLVED** by R19.
- **INFO-1** (dual rule numbering) — unchanged, still workable
  with the "Autonomy Rule N" qualifier convention.
- **INFO-2** (sprint-review-next commit-before-gate) — unchanged,
  intentional pattern.
- **INFO-3** (dev.md stale coding-conventions cross-reference) —
  unchanged, out of scope for this hardening pass.

### What is additionally guaranteed now

- Fresh `/ai-dlc-setup` runs leave no unresolved
  `{context_thresholds}` or model-template placeholders.
- Post-compact / handoff recovery guidance in QUICKSTART.md is
  consistent with SKILL.md Rule 10 — a new user reading
  QUICKSTART gets snapshot-aware resume instructions, not
  pre-Rule-10 advice.
- Fallback-mode reminder arithmetic is deterministic across
  agents; R8 recurrence doesn't depend on a lead's subjective
  estimate.
- Brownfield-a's first gate refreshes the snapshot like every
  other gate.

No new honest-contract caveats. The R1–R12 dependency re-verification
checklist still applies when Claude Code updates.

---

## 2026-04-17 Follow-up (R20)

R1–R19 hardened the reminders, snapshot contract, and recovery
protocol, but left the user as the sole actor who can convert a
confirmed red-threshold crossing into an actual handoff. On long
sprints — especially during multi-story implementation or
multi-pass adversarial review — a confirmed red can sit for hours
while the lead keeps working, because the reminder is
non-blocking and the handoff is user-initiated. R20 adds an opt-in
automatic execution path for the Rule 10(a) procedure at defined
safe seams.

### R20 — Auto-handoff at safe seams (opt-in)

**What changed.** A new setting `auto_handoff_mode` was added to
the CLAUDE.md Session Model block as template variable
`{auto_handoff_mode}`, populated by `/ai-dlc-setup` Step 2. A
shared "Auto-handoff evaluation" helper was added to
`gate-validation.md` parallel to the existing "Sub-step snapshot
update" helper. Four safe seams across the pipeline were wired to
invoke the helper. SKILL.md Rule 10 now cross-references the
feature and restates the binding constraints directively.

**Three modes, and which is default:**

- `off` — Auto-handoff never fires. Yellow and red reminders remain
  non-blocking; the user decides when to handoff. This is the
  pre-feature behavior, preserved exactly.
- `deploy-only` — Auto-handoff fires only at `deploy-validate.md`
  Step 0 pre-flight when the existing hard gate cannot be
  satisfied. No other evaluation points.
- `safe-seam` — Auto-handoff evaluates at every safe seam and
  fires when preconditions hold. This is the default for new
  installs.

Upgrade defaults:

- Fresh install (no prior AI/DLC): `safe-seam`.
- Upgrade with existing value detected in archive: the detected
  value, confirmed with one keystroke.
- Upgrade from pre-feature install (no `auto_handoff_mode` in
  archive, but `_divergence/.claude/skills/ai-dlc/SKILL.md`
  present): `off`. Returning users opt in deliberately; no silent
  migration to `safe-seam`.

Detection uses
`docs/pre-ai-dlc/<latest>/_divergence/.claude/skills/ai-dlc/SKILL.md`
as the prior-AI/DLC-install marker, plus a grep of the flat-archived
CLAUDE.md for a literal `auto_handoff_mode:` line.

**Safe seam evaluation points.**

- **Seam A** — `deploy-validate.md` Step 0 pre-flight context
  check, invoked when the existing hard gate cannot be satisfied
  via user-shared `/context` or an explicit handoff. Evaluates
  under `deploy-only` or `safe-seam`.
- **Seam B** — end of the invoking step, immediately before
  `gate-validation.md` is called. Applied in every validation-cycle
  step file: `discovery.md`, `research-requirements.md`,
  `architecture.md`, `stories-test-strategy.md` (both UI and
  no-UI exits), `sprint-review-next.md`, `sprint-review.md`,
  `doc-repair-backfill.md`. Evaluates under `safe-seam` only.
  `implementation.md` does not invoke `gate-validation.md`
  directly (the Phase 3→4 gate lives in `sprint-review.md`), so
  Seam B lives at sprint-review's pre-gate call rather than at
  implementation's end.
- **Seam C** — after each story transition in `implementation.md`
  Step 6, once the sub-step snapshot update has completed.
  Evaluates under `safe-seam` only.
- **Seam D** — between adversarial review passes in every
  multi-pass validation cycle, after each sub-step snapshot
  update. Evaluates under `safe-seam` only.

**Precondition-gated firing model.** Every seam is an EVALUATION
point, not an unconditional handoff. The shared helper evaluates
seven preconditions in order and short-circuits on the first
failure with CONTINUE (no-op). Preconditions:

1. Mode permits firing at this seam.
2. `context_reminders_sent == red` in the snapshot — equivalent to
   red confirmed under Mode 1 because Check 14 does NOT advance
   this field under Mode 2. This precondition alone is why Mode 2
   estimates cannot trigger auto-handoff.
3. Snapshot is current (Check 15 passed on the last gate, or the
   sub-step snapshot update preceding this seam just ran).
4. No gate validation currently executing.
5. No deployment currently executing.
6. No teammate awaiting lead orchestration response.
7. Not at any of the four Rule 7 pause points.

Preconditions 4 and 5 are satisfied by-construction (seam
placement). The helper still fails closed on caller bugs. The
remaining five are runtime-evaluated.

**What auto-handoff guarantees.**

- Under `safe-seam` with Mode 1 red confirmed, the lead will
  commit work, finalize the snapshot, emit the distinguishing
  auto-handoff line, and emit the Rule 10 resume prompt at the
  next safe seam it reaches. The session ENDS rather than
  continuing to degrade.
- Auto-handoff output is distinguishable from a human-requested
  handoff: the line preceding the resume prompt names the mode,
  the seam, and the confirmed token count from the most recent
  user-shared `/context`.
- Mid-gate and mid-deployment are excluded by construction. No
  seam fires inside `gate-validation.md` Check 1–15 or inside
  `deploy-validate.md` Steps 1–5.
- Mode 2 fallback estimates cannot trigger auto-handoff. The
  precondition reads a snapshot field that Check 14 only advances
  under Mode 1.

**What remains manual.** Resume itself is NOT automated. The user
opens a new conversation and pastes the resume prompt. The
incoming lead reads the snapshot and continues per the existing
`route.md` Step 0 / Step 0a integrity checks. Auto-handoff closes
the "user sits on a confirmed red because nobody pulled the
trigger" failure mode; it does not make recovery free.

**Dependency on Mode 1.** The feature deliberately cannot fire
without a user-shared `/context` confirming the red threshold.
Mode 2 advisory estimates may prompt the user to share `/context`,
which (if shared and above red) converts to Mode 1 and allows
auto-handoff to fire on the next seam evaluation. Firing
auto-handoff on an unverified estimate would break the contract
the reminders already carry: fire state advances only on confirmed
crossings. R20 preserves that contract.

> **Superseded by R28 (v0.36.0).** Mode 2 is deleted and Mode 1 is
> demoted to optional confirmation. The precondition now reads
> `last_level` from the context sensor's sidecar. The contract it
> protected — fire state advances only on confirmed crossings — is
> strengthened, not weakened: every advance is now a direct
> measurement of resident context rather than a human paste. See
> "R28" below.

**Manual walkthrough — three modes, red-threshold crossing at an
adversarial review pass boundary:**

- `off`: Lead emits the Rule 10(c) red reminder per Check 14. The
  user reads it, chooses to continue, `/compact`, or request
  handoff. Auto-handoff never evaluates. Pre-feature behavior
  preserved.
- `deploy-only`: Same as `off` at Seams B/C/D — adversarial review
  pass seam evaluates but the mode gate returns CONTINUE. Lead
  keeps working. At the next deployment, Seam A evaluates;
  preconditions hold; auto-handoff fires with label
  `deploy-validate Step 0 pre-flight`. Session ends before
  deployment begins, forcing a fresh-session deployment per R10.
- `safe-seam`: Adversarial pass completes; sub-step snapshot
  update runs; Seam D evaluates immediately after. Mode permits,
  red confirmed under Mode 1, snapshot fresh, no gate in-flight,
  no deployment in-flight, no teammate blocking, not in a pause
  point. Auto-handoff FIRES. Lead commits, finalizes snapshot,
  emits the auto-handoff line naming mode + seam + token count,
  emits the resume prompt. Session ends. User pastes the resume
  prompt into a new conversation; incoming lead continues from
  the next adversarial pass.

The dependency re-verification checklist still applies. One
additional item is now load-bearing: Check 14's Mode 1/Mode 2
distinction. If a future change advances `context_reminders_sent`
under Mode 2, the Mode-1-only guarantee breaks and R20's
contract is violated. Preserve the distinction.

---

## 2026-04-18 Follow-up (R21)

R3 landed the post-compact verification turn as a mandatory pause —
the lead re-read the snapshot, output current step / last gate /
in-flight sub-step / branch + commit, then paused with *"Does this
match your last state? Reply `proceed`, `correct <what>`, or
`handoff`."* The pause was specified to surface summary drift
before any post-compact action. On closer analysis, the pause's
rescue capability for the drift class it protected against is
overstated. R21 removes the pause while keeping the protections
that do real work.

### R21 — Remove the post-compact verification pause

**What changed.**

- `SKILL.md` Rule 7 moves from four pause points to three. Pause
  point (d) (post-compact verification) is removed. The Rule 10
  cross-reference to the Post-compact recovery no longer says
  "executes the verification turn and pauses per Rule 7(d)"; it
  says the lead outputs the verification turn content and proceeds
  immediately. Auto-handoff text and the summary enumeration at
  the end of Rule 10 now say "three pause points" and "not a
  fourth pause point".
- `CLAUDE.md.template` Post-Compact Recovery Protocol keeps the
  snapshot re-read and verification turn output as mandatory,
  removes the mandatory pause, and states the lead proceeds
  immediately in the same response. The user retains the ability
  to interrupt on the next turn with `correct <what>` or
  `handoff`.
- `QUICKSTART.md.template` "Key design principles" updates from
  four pause points to three. A short note explains post-compact
  recovery still outputs a verification turn for transparency but
  does not gate the pipeline. The Context Window Guide's "Recovery
  from `/compact`" bullet drops the "pauses for the user to
  confirm" framing.

**Why R3's pause requirement was overstated.** R3 framed the pause
as a rescue for conversation-only state loss during compaction.
Handoff to a new session does not rescue that class of drift
either — conversation-only state was never in the snapshot, and
neither path (proceed through the pause, or handoff) brings it
back. Both compact-plus-proceed and handoff-to-new-session lose
the same state. A mandatory pause that gates the pipeline on a
user reply the user usually cannot meaningfully provide is a pause
tax, not a rescue.

**What remains in place as protection.**

- **Snapshot re-read (mandatory).** The lead MUST read
  `_bmad-output/pipeline-snapshot.md` in full as its first action
  after a `/compact` or auto-compact event. This catches detectable
  drift against on-disk state (git branch, sprint-status.yaml,
  story files, gate log) without requiring user input. This is
  the protection that does real self-correction work.
- **Verification turn output (mandatory).** The lead MUST output
  current step file, last completed gate with timestamp, any
  in-flight sub-step from Recent Activity, and current git branch
  and last commit. An engaged user sees this output and can
  interrupt on the next turn if they observe something wrong. The
  verification turn gives the user a detection window without
  gating the pipeline.
- **Rule 10(a) handoff remains available.** Handoff is a
  user-initiated action the user MAY request at any time,
  including immediately after reading a post-compact verification
  turn. It is not a rescue mechanism for conversation-only state
  loss — handoff and proceed lose the same state — but it remains
  the escape hatch for a user who chooses to start a fresh session
  for unrelated reasons.

**Pause points in the updated Rule 7.** The three pause points in
SKILL.md Rule 7 after R21 are the complete set:

- (a) Ambiguity resolution (Rule 4)
- (b) Production Validation Checkpoint (Rule 6)
- (c) Retro commentary prompt

No fourth pause point exists. Auto-handoff and Rule 10(a) handoff
are session-terminating actions, not pauses. Yellow and red
reminders are non-blocking output, not pauses.

**Backward compatibility.** Projects that installed AI/DLC before
R21 have the R3 pause in their CLAUDE.md. Those installations
continue to function — the pause was itself not harmful, only more
cautious than necessary. No migration is required. Users who
re-run `/ai-dlc-setup` against an existing install MAY receive the
updated CLAUDE.md template during any future re-install. R21 does
not require setup-wizard changes.

**One stale reference remains.** `gate-validation.md`
"Auto-handoff evaluation" precondition 7 still lists "the
post-compact verification turn" among the Rule 7 pause points
whose active presence returns CONTINUE. Post-R21 the verification
turn is instantaneous output rather than a pause, so this
reference never fires in practice. The reference is inert but
semantically stale; a future cleanup pass may update the text to
match the three-point Rule 7 enumeration. Out of scope for R21.

**Dependency re-verification checklist unchanged.** R1–R12's
checklist still applies. R21 does not change the
CLAUDE.md-survives-compact, `/context` accuracy, or
system-reminder-injection dependencies.

---

## 2026-04-18 Follow-up (R22)

R1–R21 hardened the reminders, snapshot contract, recovery protocol,
and auto-handoff path. They left one assumption unexamined:
**CLAUDE.md as the survival surface.** The R3 design placed the
Post-Compact Recovery Protocol in CLAUDE.md specifically because it
had to survive compact. That framing overstated what compact removes.
Per Anthropic's Claude Code documentation, invoked skills are
re-attached after auto-compact (first 5,000 tokens of each, within a
25,000-token combined budget across invoked skills). Skills survive
compact. CLAUDE.md is not the only survival surface.

This has a corollary the design did not face until R22: **CLAUDE.md
auto-loads on every session, whether or not `/ai-dlc` is invoked.**
An engineer working on an AI/DLC-installed project without invoking
the pipeline gets all the AI/DLC rules bled into their context.
Rule 11(b) preamble, Rule 12 escalation tiers, Rule 3 no-stalling,
post-compact recovery directives -- all of it -- applies to
non-pipeline sessions because CLAUDE.md cannot scope itself.

R22 relocates the AI/DLC operating rules from CLAUDE.md to SKILL.md
so the rules load ONLY when `/ai-dlc` is invoked. CLAUDE.md becomes
a thin template of project-general configuration (project identity,
deployment commands, operations protocol, coding conventions
pointer, key references).

### R22 -- Relocate AI/DLC operating rules to SKILL.md

**What changed.**

- `templates/CLAUDE.md.template` trimmed from ~5,200 tokens to ~880
  tokens. Retains project identity placeholder, Project Operations
  Protocol, deployment commands, coding conventions pointer, and
  Key References. A new section points engineers at SKILL.md for
  pipeline rules and explains the scoping model: rules load only
  when `/ai-dlc` is invoked.

- `core/skills/ai-dlc/SKILL.md` restructured to hold the pipeline
  rules that previously lived in CLAUDE.md. The ten Critical Rules
  and eleven Autonomy Rules merged into a single unified rule set
  of eighteen rules, resolving the dual numbering overhead flagged
  as INFO-1 in the 2026-04-16 compliance review. Rules 1-13 plus
  the Handoff Protocol section plus the Post-Compact Recovery
  Protocol fit within the first 5,000 tokens of the file. Rules
  14-18 sit past the 5K boundary and may be dropped by re-attachment
  after compact; they are operational quality-of-life rules
  (multi-sprint phasing, changelog habit, file-write sizing, rule
  style guidance) rather than immediate-flow directives. The file
  explicitly documents the re-invocation fallback: if content
  appears missing after compact, re-invoke `/ai-dlc`.

- `core/skills/ai-dlc/research-citations.md` added as a new
  supporting file. The research citations that previously lived in
  Rule 10's footnote move here, referenced from SKILL.md but not
  loaded automatically. Keeps SKILL.md under the 5K budget.

- `core/skills/ai-dlc/steps/gate-validation.md` gains Check 3a
  (story validation origin check), placed after Check 3 to avoid
  renumbering existing Checks 4-15. The check fires only at
  story-level validation gates. This is where the CLAUDE.md "Story
  Validation Origin Check" section moves to.

- `templates/coding-conventions.md.template` gains a Pre-Deploy
  Schema/API Field Check section between API conventions and
  Production Integrity Tests. The CLAUDE.md section with the same
  name moves here and gains directive language (verification method
  examples, evidence requirement, severity classification).

- `core/team-roles/code-reviewer.md` gains a mandatory severity
  classification entry for missing pre-deploy field verification,
  parallel to the existing Unverifiable API Field Names entry.

### What is preserved

- Post-Compact Recovery Protocol behavior is unchanged: read
  snapshot, output acknowledgment, output verification turn, proceed
  immediately (no pause). The directive text moves from CLAUDE.md to
  SKILL.md; the pipeline's behavior is identical.

- All gate-validation.md Checks 1-15 continue to work as before.
  Check 3a is additive and self-scopes to story gates only.

- `/ai-dlc-setup` continues to populate the CLAUDE.md template
  variables that remain: `{project_identity}`,
  `{project_operations_protocol}`, `{deploy_command}`,
  `{smoke_test_command}`. The removed template variables
  (`{context_thresholds}`, `{auto_handoff_mode}`) move their
  authoritative home to gate-validation.md and SKILL.md; the setup
  wizard no longer needs to populate them in CLAUDE.md.

- Auto-handoff configuration and mode semantics: the authoritative
  location is now SKILL.md Handoff Protocol section "Auto-handoff
  (configurable via `auto_handoff_mode`)" plus gate-validation.md
  "Auto-handoff evaluation". The CLAUDE.md Session Model block is
  removed; its content duplicated gate-validation.md Check 14 and
  can be dropped without loss.

### What this fixes

**Engineer B bleed-through.** An engineer working on an AI/DLC
project without invoking `/ai-dlc` no longer has pipeline rules in
context. CLAUDE.md provides only project configuration; no autonomy
rules, no session model, no recovery protocol. The `/ai-dlc` skill
description is still visible in the skill listing (per Claude Code
documentation, descriptions are always loaded) but the rule text
loads only on invocation.

**Dual rule numbering.** The INFO-1 finding from 2026-04-16
persisted through R13-R21 because renumbering touched every step
file. R22 accepts the renumbering cost as part of the larger
restructure. Unified Rule N is now unambiguous.

**SKILL.md budget pressure.** The previous SKILL.md was already
over the 5K re-attachment budget. Content past 5K was silently
dropped after compact, which likely affected the research citations
footnote and parts of the auto-handoff binding constraints. R22
explicitly orders SKILL.md so the critical-flow content fits within
5K, with less-critical content past the boundary and a documented
re-invocation fallback.

### What this does NOT fix

- **Re-attachment budget is still a hard cap.** Projects that add
  project-specific operating rules to CLAUDE.md will not have those
  rules in SKILL.md's 5K budget. They live in CLAUDE.md and load
  on every session (whether `/ai-dlc` is invoked or not), which is
  fine for project-scoped rules but by construction means the
  engineer-B bleed-through returns for any project-specific rule
  text a consumer adds.

- **The re-invocation fallback requires the user to act.** If after
  compact the lead notices rule content is missing (e.g., it cannot
  recall Rule 14's multi-sprint phasing guidance when a large
  feature comes in), the recovery path is to ask the user to
  re-invoke `/ai-dlc`. This is an operational norm, not an
  automated recovery. It is documented in the Post-Compact Recovery
  Protocol.

- **Combined skill budget.** If a session invokes many skills, the
  25K combined budget can push `/ai-dlc` out of the re-attachment
  set entirely. The re-invocation fallback handles this too, but
  the user has to notice the symptom and act.

### Step file audit required before landing

The unified rule numbering changes break cross-references in step
files that say "Autonomy Rule N" (referring to CLAUDE.md) or "Rule
N" (referring to either file). A mechanical audit is required:

```bash
grep -rn "Autonomy Rule\|SKILL.md Rule\|CLAUDE.md Rule" \
  core/skills/ai-dlc/ 2>/dev/null
```

Update each match to reference the unified rule number. Expected
mapping (from the unified SKILL.md rules):

| Old reference | New reference |
|---|---|
| CLAUDE.md Rule 1 (walk through) | Rule 6 |
| CLAUDE.md Rule 2 (apply improvements) | Rule 7 |
| CLAUDE.md Rule 3 (validation cycle) | Rule 8 |
| CLAUDE.md Rule 4 (escalate via file) | Rule 12 |
| CLAUDE.md Rule 5 (document changes) | Rule 15 |
| CLAUDE.md Rule 6 (err on doing) | Rule 16 |
| CLAUDE.md Rule 7 (large files) | Rule 17 |
| CLAUDE.md Rule 8 (requirements WHAT/HOW) | Rule 13 |
| CLAUDE.md Rule 9 (multi-sprint) | Rule 14 |
| CLAUDE.md Rule 10 (seek clarity) | Rule 11 |
| CLAUDE.md Rule 11 (hard directive) | Rule 18 |
| SKILL.md Rule 1 (read CLAUDE.md) | Rule 1 |
| SKILL.md Rule 2 (single conversation) | Rule 2 |
| SKILL.md Rule 3 (autonomous gates) | Rule 9 |
| SKILL.md Rule 4 (seek clarity) | Rule 11 (merged with CLAUDE Rule 10) |
| SKILL.md Rule 5 (requirements locked) | Rule 13 (merged with CLAUDE Rule 8) |
| SKILL.md Rule 6 (production validation) | Rule 10 |
| SKILL.md Rule 7 (pause points) | Rule 3 |
| SKILL.md Rule 8 (every step in full) | Rule 4 |
| SKILL.md Rule 9 (follow routing) | Rule 5 |
| SKILL.md Rule 10 (handoff) | Handoff Protocol section (no number) |

### Dependency re-verification checklist

The R1-R12 dependency re-verification checklist still applies when
Claude Code updates. R22 adds one additional item to watch:

- **Re-attachment budget.** If Claude Code changes the per-skill
  5,000-token limit or the 25,000-token combined budget, SKILL.md's
  ordering invariant (critical rules fit in first 5K) may break.
  Re-read `https://code.claude.com/docs/en/skills` "Skill content
  lifecycle" before landing any SKILL.md change that grows the file
  past its current size.

### Manual walkthrough -- three scenarios

- **Engineer A invokes /ai-dlc on a configured project.** Session
  starts. CLAUDE.md auto-loads (project config only). `/ai-dlc`
  loads the skill; SKILL.md content enters the conversation.
  Pipeline rules are now in context. Runs normally.

- **Engineer B opens the same project, works on an ad-hoc change
  without invoking /ai-dlc.** Session starts. CLAUDE.md auto-loads
  (project config only). No pipeline rules. Engineer B's work is
  not subject to Rule 11(b) preamble, Rule 12 escalation tiers, or
  Rule 3 no-stalling. They see the `/ai-dlc` skill description in
  the skill listing but the rule text is not loaded.

- **Engineer A's session crosses the red threshold and auto-compact
  fires.** Skills re-attach: `/ai-dlc` gets the first 5,000 tokens
  (Rules 1-13, Handoff Protocol, Post-Compact Recovery). Recovery
  protocol reads the snapshot, outputs acknowledgment and
  verification turn, proceeds. If the lead later needs Rule 14
  (multi-sprint phasing) and it appears missing from context, the
  lead asks the user to re-invoke `/ai-dlc`.

---

## 2026-04-18 Follow-up (R23)

R22 relocated pipeline rules from CLAUDE.md to SKILL.md but did not
update the `/ai-dlc-setup` wizard to recognize pre-R22 CLAUDE.md
sections that had moved. On upgrade from a pre-R22 install, Step 0a
could classify old Autonomy Rules, Session Model, Post-Gate
Deployment, Post-Compact Recovery Protocol, Story Validation Origin
Check, or inline Pre-Deploy Schema/API Field Check content as
"project-specific rules" and attempt to re-inject them into the new
thin CLAUDE.md or the new coding-conventions.md. R23 closes that gap.

### R23 -- Pre-R22 section exclusion in Step 0

`core/skills/ai-dlc-setup/SKILL.md` Step 0a gained an exclusion list
for pre-R22 section headers, gated on `prior_ai_dlc_install == true`.
The list enumerates each section that R22 relocated, maps it to its
new authoritative location, and instructs the wizard to skip the
entire section body during absorption. Detected-and-excluded
sections are recorded as `r22_excluded_sections` for display in the
absorption summary.

Step 0c gained a duplicate guard for Pre-Deploy Schema/API Field
Check. The new `coding-conventions.md.template` ships with this
section baked in; on pre-R22 upgrades, the archived coding-
conventions.md version is skipped to prevent duplication. On non-
AI/DLC upgrades (`prior_ai_dlc_install == false`) the archived
version is treated as user content and surfaced in Step 7 for
reconciliation.

Step 0e absorption summary gained two new blocks, both conditional
on `prior_ai_dlc_install == true`: a list of pre-R22 sections that
were not absorbed (with their new locations) and a list of duplicate
guards that fired. Returning users now see, in one place, what the
wizard recognized as relocated AI/DLC content versus what it
absorbed as project-specific.

The `prior_ai_dlc_install` flag, set in Step 0a but previously
consumed only by auto_handoff_mode handling, now has two additional
consumers: the Step 0a exclusion list and the Step 0c duplicate
guard.

### What this fixes

Upgrade from pre-R22 to post-R22 no longer requires manual cleanup
of duplicated or re-injected rule text. The install flow plus the
wizard produce the same end state as a fresh install: thin CLAUDE.md
with only project configuration, pipeline rules in SKILL.md at
unified numbering.

### What remains outside R23 scope

- Generalizing the section-provenance model for future relocations
  (Option B in the R23 design conversation). R23 is R22-specific.
  If a future change relocates rules again, Step 0a needs another
  surgical edit.
- Upgrade-specific routing (Option C). Pre-R22 upgrades still run
  the full wizard starting from Step 0; there is no dedicated
  upgrade flow.
- Automated cleanup of pre-R22 content that users may have
  customized and want to preserve elsewhere. The archive at
  docs/pre-ai-dlc/<timestamp>/ remains the source of truth for
  anything a user wants to salvage manually.

## R28 — Context sensor: measure, don't estimate (v0.36.0)

Rule 2(b)/(c) reminders exist so the high-fidelity handoff
(`/clear` + `/ai-dlc resume`) gets first refusal before Claude Code's
auto-compact takes the lossy path. Until R28 the only authoritative
trigger was the user pasting `/context`. Measured across 243 real
consumer sessions carrying `usage` data (the `graph` project):

| Fact | Value |
|---|---|
| Sessions crossing yellow (120K) | 219 |
| Sessions crossing red (200K) | 184 |
| `/context` invocations by the user, ever | 2 |
| Mode 2 silent at the true yellow crossing | 108 of 219 |
| Mode 2 median relative error | +69% (p90 +134%) |

The reminders almost never fired, so the ordering invariant was
decorative. This is the gap R28 closes.

**Mechanism.** Hook stdin carries no token counts — the shared schema
is `session_id, transcript_path, cwd, prompt_id, permission_mode,
agent_id, agent_type, effort` (extracted from the Claude Code 2.1.206
binary). But it carries `transcript_path`, and every assistant message
in the transcript carries `message.usage`. Claude Code's own context
figure is `input_tokens + cache_creation_input_tokens +
cache_read_input_tokens` from the last main-thread assistant message.
`ai-dlc-context-sensor.sh` (a Stop hook) computes exactly that, so its
reading equals `compactMetadata.preTokens`. Verified against a real
6.5MB transcript: 248,721 measured, 248,721 actual, in 59ms.

**Why not the statusLine.** Its stdin does carry an official
`context_window` object (`total_input_tokens`, `context_window_size`,
`used_percentage`) plus `exceeds_200k_tokens`. But its stdout is
display-only and never reaches the model; it occupies a single global
slot users typically fill with their own tool; `install.sh`'s jq merge
does not manage the `statusLine` key; and it does not run in the
headless session-driver environment where AI/DLC runs unattended. Its
data is derivable from `transcript_path`, which every hook receives.

**Why a Stop hook, and why it works alongside a blocking sibling.**
Stop fires once per assistant turn (`PostToolBatch` fires per tool
batch — many times per turn, for a number that only moves per turn).
At Stop time the latest assistant `usage` line is always already in the
transcript (verified 0–3 lines back across 2,472 real stop entries).
Critically, the Stop result loop collects each hook's
`additionalContexts` independently of whether a sibling hook sets
`preventContinuation`, so the reminder reaches the model even on the
turns `ai-dlc-continue.sh` blocks — which, in autonomous mode, is
nearly all of them.

> **Superseded by R29 (v0.36.1).** "Stop fires once per assistant turn"
> assumed turns are frequent. They are not on a long autonomous run: a
> real `graph` session went 169 `tool_use` messages deep with zero
> `Stop` boundaries and the sensor never sampled. The hook now also runs
> on `PostToolBatch`. See "R29" below.

**The ~31,000-token sensor reserve.** Claude Code compacts at
`effectiveWindow - 13000` (`G_o(e,t) = e - 13000`). But the quantity
this hook measures sits a further ~18,000 below that at fire time: the
check adds an output allowance before comparing. Measured on two
independent windows — 287,000−268,892 = 18,108 and 987,000−969,084 =
17,916. So the ceiling visible to a transcript-derived reading is
`effectiveWindow - 31,000`. The `-13000` invariant in
`validate-compact-window.sh` is unchanged and remains correct; 31,000
is used only by the runtime `compact_imminent` backstop.

**Model-row inference.** The transcript records `claude-opus-4-8` for
both the 200K and the 1M variant; the `[1m]` suffix is stripped and no
window size appears anywhere in it. The two errors are asymmetric:
assuming 200K on a 1M model fires reminders early (noisy, non-blocking),
while assuming 1M on a 200K model puts red at 200,000 above a compact
threshold of 187,000 — red would never fire before compaction, the exact
failure the ordering invariant prevents. So the sensor assumes 200K and
upgrades only on proof: a reading ≥ 187,000 is impossible on a 200K
model. The proof is cached in `_bmad-output/.context-sensor-model`, so a
project pays the early-reminder noise at most once. `AI_DLC_MODEL_ROW`
pins it explicitly. The `compact_imminent` backstop is suppressed while
the row is merely assumed, since `effectiveWindow` would be a guess.

**Fire state moved off the snapshot.** The snapshot's Context Reminders
fields are lead-written at gates — a handful per session against a p50
of 242 assistant turns — far too coarse to dedupe a per-turn sensor.
The hook owns `_bmad-output/.context-sensor-state` and the 50K-token /
20-turn recurrence. Check 14 now reconciles the snapshot from it. The
sidecar self-heals: a reading that drops by more than 50,000 tokens
means compaction or `/clear`, and resets the level to `none`.
`ai-dlc-recover.sh` also removes it on `SessionStart(compact)`.

**Consequence for auto-handoff.** The `deploy-only` precondition
formerly read "red confirmed under Mode 1", justified by the fact that
Mode 2 never advanced the field. It now reads `last_level` from the
sidecar. The guarantee is strengthened: every advance is a direct
measurement of Claude Code's own figure rather than a human paste.

**Measured lead time.** From yellow (120K) to compaction: p50 138
turns. From red (200K): p50 79 turns. Context grows ~1,200 tokens/turn
(p50) and the resident floor is ~69,215 (p50). There is ample room for
a non-blocking reminder to change the outcome.

## R29 — Imminent band opens early; sensor samples on PostToolBatch (v0.36.1)

Two defects surfaced from real `graph` compactions after R28 shipped.

**The imminent backstop could essentially never fire.** R28 set it at the
sensor-visible ceiling `effectiveWindow - 31,000`. But compaction preempts the
turn that would cross it. The four real auto-compactions on `graph` last measured
268,892 / 267,719 / 267,445 / 267,023 against a 269,000 ceiling — every one below
the trigger. And even the one case that did reach the ceiling (the 1M session at
969,084 ≥ 969,000) fired on the very next model request, destroying the injected
directive along with the window.

Fix: open the critical band at `effectiveWindow - 31,000 - 20,000`. At the
measured p50 growth of ~1,200 tokens/turn the 20,000-token lead buys ~16 turns —
room to act. All four real compactions fall inside it. `imminent` is a level of
its own ranked above red, so entering the band always fires on first crossing; as
a red variant it would have waited on red's 50,000-token / 20-turn recurrence
delta, and a lead that already saw red at 200,000 could reach compaction unwarned.
In the band the hook directs the lead to refresh `pipeline-snapshot.md` before its
next action — the snapshot is what `ai-dlc-recover.sh` re-reads, and on `graph` its
write cadence has a p90 gap of 12.9h against compactions 1–4h apart, so a stale
snapshot is recovered faithfully and is still wrong.

**A Stop-only sensor is blind to turn-less runs.** The sensor was a `Stop` hook,
and Stop fires only at `end_turn`. Session `bd13dc14` ran `/ai-dlc resume` →
auto-compact across 169 consecutive `tool_use` messages with zero `end_turn`
boundaries, so the sensor never sampled; context climbed 77K → 270K unwarned.
Recovery still landed (`injected_bytes: 3873`, no degradation), and the prior
session (13 Stops) had fired yellow+red correctly — the hook worked, it just never
ran. Across `graph`, 19 of 185 red-crossing sessions have ≤2 Stop boundaries, and
those turn-less autonomous runs are the highest-risk ones.

Fix: wire the hook to `PostToolBatch` as well as `Stop`. PostToolBatch fires once
per tool batch, before the next model request. Verified with a live headless probe
that its `additionalContext` reaches the model mid-run (the model echoed an
injected marker). The hook echoes whichever event invoked it as
`hookSpecificOutput.hookEventName`.

To bound hot-path cost, the `PostToolBatch` tail-read is throttled: it runs only
once the transcript has grown ~512,000 bytes (`AI_DLC_SENSOR_THROTTLE_BYTES`)
since the last read, tracked as `last_read_size` in the sidecar. `Stop` is never
throttled. Measured on a 2.7MB transcript: full read 60ms, throttled skip 27ms.
The shared sidecar dedups, so the second event samples often but injects only on a
level change or the recurrence delta; the first sample of a session (no sidecar)
is never throttled. Transcript bytes vastly outpace token growth (tool outputs),
so a 512KB throttle is far tighter than the token thresholds it feeds.

The `PostToolBatch` template block propagates to existing consumers with no
migration: `settings-merge.sh` and `install.sh` union the event keys and strip
per-block, so the sensor lands once on each event without duplication.

## 2026-07-10 Follow-up (R30) — Resident-path rationale relocation

Design history and origin context that had accreted into the resident
LLM-consumed skill files, relocated here so a fresh lead never pays for it per
dispatch. This is the "narrative drift" cleanup class `rule-authoring.md`
defines. Rule 26(c) `Minimum mechanism` blocks were deliberately **left inline**
at their machinery sites (26(c) requires the contract "at introduction", and the
retro audit flags machinery lacking it), so only origin/change-history and
worked-proof narrative moved. The compact-window ordering invariant moved into R2
above; the rest is captured here by source.

### From SKILL.md

- **Single-voice sub-skill binding (moved from L662).** The subagent-dispatch
  requirement for the three single-voice sub-skills *reverses* an earlier "invoke
  inline, do NOT route through Agent" rule. The reversal is because inline
  invocation is solo by construction — there is no internal spawn to make it an
  independent critic — which is exactly the failure the current rule forbids.
- **Rule 25(a) no-loss archival (moved from L903–904).** The "move to
  history, never delete" instruction *supersedes* an older "do not rewrite
  existing content" phrasing; the intent was always *no requirement loss*, not
  *unbounded growth*.
- **Rule 27(b) retirement duty evidence (moved from L1014).** A real consumer
  (graph) carried an absorbed-but-not-retired extension for 22 releases, during
  which it silently forked from and then contradicted the core text it once
  matched — the concrete case behind the mandatory retirement.
- **Rule 27 catch-22 evidence (moved from L1028).** The "in-place authoring
  clobbered by the next upstream pull" failure was observed regrowing on graph;
  the 26(c) `Failure caught:` line it annotated stays inline, minus the evidence
  citation.
- **Rule 28 delegation evidence (moved from L1077).** The context-saturation
  failure the delegation contract catches is the observed action-heavy-misread
  and token-saturation failure modes; the 26(c) line stays inline, minus the
  citation.
- **Handoff-protocol layout constraint (moved from L377–382).** The handoff and
  context-warning rules are "second-tier by design" — re-encountered at the next
  gate via `gate-validation.md` Check 14 and `_gate-procedures.md`, so they may
  sit past the 5,000-token post-compact re-attach boundary. The recovery protocol
  above them may not: it must survive the event it handles, so nothing may be
  inserted ahead of it without re-measuring the re-attach budget. This is a
  maintainer editing constraint, not a lead instruction.

### From gate-validation.md

- **Gate-type slicing framing (moved from L17–20).** The slice is a
  conditional-load, not a reduction — no check text is edited; a check merely
  stops occupying the window on gates where its own scope clause would make it a
  no-op anyway. (Full spec: `docs/v0.24.0-gate-validation-slicing-spec.md` §5.)
- **Over-slice mechanics (moved from L66–75).** H1 only catches a check the
  manifest *marks required* but the loader failed to load; it cannot catch a
  manifest row that wrongly omits a check — hence over-inclusion is safe and
  under-inclusion is the silent bug. Checks 8/9 sit in both `implementation`
  (vacuous pre-deploy) and `retro` (post-deploy evidence); Check 17 sits in
  `planning`, `story`, and `retro` (PRD gate, story-readiness gate, retro gate).
- **Check 12 emit-scope rationale (moved from L447–448).** Checks 12–15 are
  bookkeeping, never defect-catchers, so they carry no efficacy signal; emitting
  a metric for the emitter (Check 12) is also circular.
- **Check 13 numbering artifact (moved from L478–481).** Check 13 is numbered 13
  to preserve existing cross-references, but its execution is deferred until the
  full 15-check cycle completes, so the announcement reflects the final count.
- **Consumer-catalog crosswalk (moved from L83–99; mechanized v0.49.0).** Consequence
  for any audit or absorption pass: a consumer MAY redefine a shared check number or
  add checks past this catalog's range, so `Check N` in a consumer's gate-log/retro/
  escalation refers to *that* consumer's catalog. Never attribute consumer
  fire-history to a distribution check by number — align by title/intent and
  confirm against the consumer's own `extensions/checks/*.md`. A consumer extension
  marked `push_candidate: false` is deliberately consumer-local and MUST NOT be
  backported (violates the layered-rulebook boundary). A check absorbed FROM a
  consumer records its origin inline via a `Graph→distribution number mapping.`
  note (Checks 20, 21). Repeatable evidence tool:
  `scripts/audit-machinery-efficacy.js` (run under `bun` for real tokenizer counts);
  see `docs/v0.27.0-machinery-efficacy-audit.md`.

  **Why this was a declaration, not a mechanism (the v0.49.0 finding).** The rule
  above told the reader not to conflate the catalogs. The reader is a lead who then
  writes a bare `Check 24: PASSED` into the gate log — so the rule placed the whole
  burden on recall at exactly the moment the number became permanent evidence, and
  prescribed no rendering that distinguished the catalogs where they are actually
  used. Three things followed, all found live on a real consumer:

  - **The number was never a referent.** Four number-shared/title-different pairs
    (20, 22, 23, 24). The "different gate types disambiguate them" luck had already
    run out: at a sprint-review gate the consumer's check 21 and core's check 21 both
    fire, and the lead had improvised `(consumer Check 21)` by hand in
    `gate-log-archive-s287.md` to tell them apart. The claim "nothing has broken yet"
    was false; it had broken and been papered over in prose.
  - **The absorption detector was edge-triggered.** `layer-drift.sh` reported an
    absorbed extension only on the single pull that landed it (`present at theirs,
    absent at base`) and joined on the NUMBER. So a check upstream absorbed under a
    *different* number was invisible forever. Two such duplicates had been carried
    silently for ~35 minor versions — and core's own prose documented both
    ("graph's Check 21 absorbed as distribution Check 20"; "absorbed from graph's
    Check 33"). Absorption is a STATE, not an EVENT: test it every pull, use `base`
    only to tag NEW-THIS-PULL vs PRE-EXISTING.
  - **One heading typo disabled four tools at once.** v0.48.0 shipped
    `### Check 24.` where every other check is `### 24.`. Every anchor extractor in
    the distribution AND the consumer-shipped layer linter keys on `^### <n>.`, so
    check 24 vanished from all of them — including the linter that would have caught
    the collision v0.48.0 itself created, and `audit-machinery-efficacy.js`, whose
    per-check token span runs to the next MATCHED header and therefore folded check
    24's entire cost into check 23. Nothing tied a heading to its `CHECK_LOADED`
    anchor; I6 in `validate-enforcement-map.sh` now does.

  **Resolve history by title, never by date.** The tempting rule — "a bare `Check N`
  written before core gained check N means the consumer's" — is sound in that one
  direction and unsound in the other: after the epoch both catalogs are live and the
  consumer keeps writing about *its own* check N indefinitely. Worse, the date oracle
  does not exist. Check 12 mandates cut-and-paste rotation of gate logs into archives,
  so `git blame` on a rotated line returns the ROTATION date, not the authorship date
  (`prd-history.md`: first commit 2026-04-10, content dated back to 2025-02-14) —
  biasing old references *newer*, i.e. toward core. The pipeline's own rotation rule
  destroys the evidence a date rule would need. Use the consumer's frozen title
  crosswalk (`extensions/README.md`) instead; a lookup has no unsound region.

  **A loose title match is worse than no title match.** When the title became a join
  key, `same_section()`'s old rule (≥2 shared tokens of the first 4) matched consumer
  check 22 "Smoke test evidence" to core check 11 "Smoke test coverage for user-facing
  changes" on `{smoke, test}` — which would have proposed *deleting* a live
  deploy-validate check on a financial system. The bar is now Jaccard ≥0.6 over
  significant tokens, OR ≥0.75 containment of the shorter title (which forgives an
  appended provenance tag like `[PI-S259-1 addendum]` without forgiving a different
  check).
- **Check 22 citation fix (deleted at L871–873, recoverable from git).** Check 22
  superseded stale "Check 15" citations in `implementation.md` that pointed at
  the snapshot-verification check by mistake — a one-time correction, not
  reusable design rationale.

### From step files (Phase B)

- **Protected-path delegation history (moved from `implementation.md` L57–58).**
  The lead reviewing the `protected-path-editor`'s diff before merge is the
  lead-owned safety that *replaced* the former lead-only execution of
  protected-path edits — Rule 28 made the edit delegable, and the diff review is
  what preserves the safety the inline execution used to provide.
- **`architecture_refs` placement rationale (moved from
  `stories-test-strategy.md` L208–210).** The field is populated at authoring
  time, where the architecture design is fresh and the touched sections are
  known, because it is the slice target dev/qa read instead of whole-reading the
  architecture doc — a large living artifact whole-read on every dispatch is the
  single largest read cost in the pipeline (Rule 25).
- **History-rotation evidence (moved from `architecture.md` L52–54).** The
  "no per-sprint Architecture Addendum" rule exists because that accretion
  pattern grew one consumer's `architecture.md` past 500K tokens, making every
  dev/qa/architect read dominate pipeline cost.
- **Next-sprint validation purpose (reworded in `sprint-review-next.md`
  L11–14).** The step validates next-sprint stories against the previous sprint
  because a multi-sprint transition must not skip the validation cycle — the
  prior sprint's implementation may have surfaced issues that affect upcoming
  stories. Kept as a plain purpose statement, dropped the "this step exists
  because" framing.

### From layer READMEs (Phase B)

- **`base_sha` poisoning evidence (moved from `overrides/README.md` L47–48).** A
  real consumer had a project-repo sha (not a distribution sha) on 5 of 12
  overrides and lost two upstream changes to a stale shadow without any warning —
  the concrete case behind "a correct `base_sha` never resolves in your own repo."
- **Extension-restriction evidence (moved from `extensions/README.md`
  L57–59).** A consumer's `artifact-consolidation-push.md` asserted three valid
  targets as an extension (no drift anchor); upstream added a fourth and both
  statements loaded — the concrete case behind "a restriction belongs in
  `overrides/`, not `extensions/`."
- **Fencing rationale Phase-1 aside (deleted from `extensions/README.md` L10,
  recoverable from git).** The clause "never the whole-rulebook tangle Phase 1
  had to untangle" referenced the original layered-rulebook migration; the
  operational point (fencing keeps `core` byte-reconcilable) stands without it.

## 2026-07-12 Follow-up (R31) — Post-compact teammate re-join (v0.50.0)

### R31 -- Verification-turn rationale relocated; In-Flight Teammates added

Two changes to the POST-COMPACT RECOVERY PROTOCOL's verification turn, both
forced by the same constraint: at HEAD the protocol ended at ~4,743 tokens with
**7 tokens of slack** under `validate-reattach-budget.sh`'s 4,750 ceiling. The
resident region is full. Anything added there must be paid for.

**Added (mechanism, stays resident).** The verification turn now names every
`In-Flight Teammates` row and whether its deliverable exists. This is the
post-compact re-join: a teammate whose deliverable file exists has DELIVERED and
must be consumed, never re-dispatched; one whose file is absent is not thereby
dead. The authoritative long form lives in `ai-dlc-recover.sh` (which has ~4.6 KB
of headroom under its own 10,000-char cap) and the rationale in
`gate-validation.md` Check 14. SKILL.md carries only the imperative, because
SKILL.md's protocol is explicitly the *fallback* for when the hook is absent.

**Relocated here (rationale, was resident).** The two sentences that explained
*why* the verification turn exists:

> The user retains the ability to interrupt on the next turn by sending a
> correction or requesting handoff. The verification turn output exists for
> transparency -- the user sees what the lead believes about current state before
> the lead acts on it.

Still true, still the reason the turn is printed. It is narrative, not mechanism:
no lead action changes if it is absent, and Rule 26(c) minimum-mechanism blocks
are the thing that may *not* relocate — this is not one. Same weighting principle
as R30: strip by load frequency, and the resident path is the most frequently
loaded text in the system.

**What this bought.** Protocol end went 19,198 → under the 19,000-byte ceiling,
restoring slack while *adding* the teammate re-join instruction.

**The failure that prompted it (S289).** The lead re-dispatched **13 of 39**
teammates in one implementation phase. It could not address a teammate, concluded
the teammate had died, and dispatched a replacement over work that was still
running or already delivered. Two causes, and the second is the one that fired:
compaction can summarize away an `agent_id`, but the *wrong join API* fails with
no compaction at all — `TaskOutput` takes a `task_id`, which only `TaskCreate`
produces, so `TaskOutput("s289-qa-1")` returns `No task found with ID` every
time. All 8 of S289's failed `TaskOutput` calls passed an agent name; all 10 that
passed a real `task_id` succeeded. The lead read the first failure as *"the
compaction killed the in-flight QA agent"* — it had not, and `implementation.md`
had told it to make that call. The deliverable path defeats both causes: it needs
no `agent_id`, takes no `task_id`, and outlives a compaction.

### R31 (cont.) — the measured failures, kept out of the resident path

The step files and SKILL.md carry the *mechanism* and the Rule 26(c)
minimum-mechanism blocks. Everything below is the narrative behind them, and it
lives here because `implementation.md` is whole-re-read after every compaction
(8 times in the S289 phase) and `gate-validation.md` 7 times — narrative in
those files is narrative paid for on every compaction, which is the very loop
v0.50.0 exists to shorten. Weight strips by load frequency (R30).

**The join-API defect.** `implementation.md` prescribed
`TaskOutput(task_id, block: true, timeout: 120000)` as the join for dev,
code-reviewer, and qa. All three are `Agent` spawns; `TaskOutput` takes a
`task_id`, which only `TaskCreate` produces. It cannot join an `Agent`. In S289:
8 `TaskOutput` calls failed with `No task found with ID`, every one having passed
a human-readable agent name; all 10 that passed a real `task_id` succeeded. The
lead read the first failure as *"s289-qa-1 no longer resolves — the compaction
killed the in-flight QA agent."* It had not. The call had never been capable of
working, with or without a compaction, and the skill had told it to make that
call. It then re-dispatched **13 of 39** teammates over work that was still
running or already delivered, and invented forensics (worktree emptiness,
transcript-staleness probes) at each of 7 compactions to guess who was alive.

Two things destroy a teammate handle, and the second is the one that bites:
compaction can summarize away an `agent_id`; the wrong join API fails with no
compaction at all. The deliverable path defeats both — it needs no `agent_id`,
takes no `task_id`, and outlives a compaction.

**The snapshot budget.** Check 14 enforces the 6k budget at gate passages, which
is frequent enough in planning. Implementation passes three gates in four hours.
The S289 snapshot grew past **200% of budget** between them and was whole-read at
each compaction — the single largest byte-injector in the session — while the
lead spent turns policing it by hand (19 validator runs, repeated trims).

**The retyped beat.** Rule 29 gave the lead a shell snippet to retype for every
join. It retyped it **75 times** (~13k resident tokens), and a retyped loop is a
loop that can be typed wrong — which is all Check C was ever policing.

**The grep-wrapped validator.** The validators print their working, so the lead
wrapped them: `validate-… | grep -E 'OVER|PASS'`, **71 times** (~26k tokens), a
fresh filter each time. A pipe hands the exit status to `grep`, so a validator
that prints FAIL and exits 1 reads as a pass. S289 had already shipped a fix
titled *"the harness could print FAIL and exit 0"* and then hand-rolled the same
pipe 71 more times. `verdict.sh` exits with the validator's own status.

**What v0.50.0 got wrong (fixed in v0.50.1).** The wait script took exactly one
path, so a wave of three teammates would have cost 3 × 110s of serialized wall
clock. The consumer chained beats into one `Bash` call instead —
`wait a.md; wait b.md` — which is 2 × 110s against a 120s budget: the harness
backgrounded it at the cap and both verdicts went to a file the lead never read.
Check A starvation, committed by the caller rather than by the loop. The lead was
not careless; a primitive that makes the correct thing expensive gets worked
around. The script now polls many paths inside ONE beat, and refuses to sleep
twice in one call (chained invocations share a parent shell, hence `$PPID`).

---

## R32 — the enforcers were named, not wired (v0.52.0)

Rationale relocated from `steps/gate-validation.md` (Check 25),
`core/scripts/validate-adversarial-convergence.sh`, and
`scripts/validate-enforcement-map.sh` (I9). Step files are re-read at every gate and
the SKILL.md resident region at every compaction; stories are paid per read, so they
live here.

### The measurement

The reference consumer was reviewed live at `0.51.0@b333c86`, mid-sprint (S290,
planning, paused at an operator handoff). Three validators were run against the
running pipeline:

| validator | findings on the live consumer | invoked at a gate? |
|---|---|---|
| `validate-steering-budget.sh` | **FAIL(A): 11 starvation violations, worst 10.0 min** | **no gate call site at all** |
| `validate-layer-entries.sh` | 5 ERRORs, 21 warnings | named in gate *prose*; the gate passed |
| `validate-enforcement-map.sh` | — | distribution-only, and the distribution **had no CI** |

`git log --all -- .github` was **empty for the project's entire history**. ai-dlc
shipped a CI *template to its consumers* while gating none of its own fifteen
validators. Every check ran only when a human remembered to type it.

### The mechanism behind three half-wired releases

`enforcement-map.yaml` recorded `enforcer:` — *who* enforces a rule — on all 38
entries, and `call_sites:` — *where the enforcer is actually invoked* — on **one**.
So "Enforced by `validate-X.sh`" was a **claim**, and nothing in the repo could tell
a claim from a wiring.

That is how `implementation.md:152` could say *"`scripts/validate-steering-budget.sh`
fails the gate on it"* while that sentence was **false at every gate, in every
phase** — the script ran only at retro, after the sprint had already paid. v0.50.0
authored the join fix against the phase where the failure was *observed*
(implementation) rather than against the invariant (Rule 29 binds anything that
dispatches). Planning dispatches most: S290 ran 28 of its 28 spawns there, and the
lead — having no prescription — hand-rolled 17 `sleep` commands, ~8 of them unbounded
`until` loops that ran to the 10-minute harness cap.

**I9/W1** makes the difference representable and then required: an
`adjudication: script` entry with no `call_sites:` is an ERROR. Run against the map
as it stood, it fails on nine entries. It would have caught v0.50.0 at authoring
time.

**What W2 deliberately does not do.** It checks that a declared call site's file at
least *names* the enforcer, which catches a fictional site. It **cannot** tell an
invocation from a prose mention — `retro.md:639` is a real indented command,
`implementation.md:152` is a sentence, and a basename grep passes both. Telling them
apart means parsing English, and a heuristic that fails closed on a legitimate new
phrasing is an unpassable gate, which gets turned off. The teeth are W1 plus the
reviewable `posture:` field, and that limit is stated in the script rather than
implied by its error message — a check whose message claims more than it verifies is
the very defect this release is about.

### Rule 8: the counts were never commensurable

S290 ran **eight** adversarial passes on one artifact. CRITICALs went
`3 → 1 → 1 → 2 → 2 → 2 → 3 → 2`, and not one pass ever stamped
`EXIT_CONDITION_MET`. The consumer's own snapshot: *"THE ARTIFACT-LEVEL CYCLE IS NOW
CLOSED BY A CRITERION, NOT BY A PASS."*

The divergence predicate was a bare count comparison — `criticals(N+1) > criticals(N)`
— with a single cause welded onto it: *"the repair step is injecting defects."* It
hard-blocked twice (p4: 2>1, p7: 3>2). **Both times the cause was false.** Pass 7,
first line, verbatim:

> *"The rise is NOT pass 6's repairs injecting defects — I probed those and they
> hold; I did not re-open them. Every new CRITICAL is in the scope the sprint ADDED
> after pass 6 closed."*

The adversary wrote **prose to override the field it had just stamped**. That is
v0.48.0's defect exactly inverted: there a cycle converged in the prose while the
field said otherwise; here the field cries divergence while the prose says the
repairs held. Both cost the operator an adjudication, and the two conditions have
**opposite remedies** — *"your repairs are bad"* versus *"the sprint grew; cut it."*

`findings_critical_prior_scope` partitions a number the adversary already produced:
of your CRITICALs, how many sit in text the previous pass also reviewed. Only those
are comparable.

- **An int, not a `scope_delta: GREW|SAME` enum.** An enum is a cheat code — an
  adversary facing a hard block stamps `GREW` and the block evaporates, with nothing
  to check it against. An integer is cross-checkable (`prior_scope ≤
  findings_critical`) and survives the mixed case (scope grew *and* the repairs
  regressed) that an enum erases.
- **No fourth verdict.** The condition is derivable from the field. Rule 26(b): the
  simpler path does not fail, so a new enum token would be unrequested mechanism —
  a MAJOR under the rung v0.51.0 itself just shipped.
- **Fail-closed default.** Absent field ⇒ `prior := crit` ⇒ the predicate degrades to
  *exactly* the pre-v0.52.0 comparison. It can only make Check C stricter, never
  laxer, so a missing field cannot be used to dodge a hard block. This is what makes
  the field safe to adopt **mid-cycle**, against S290's eight already-stamped passes,
  with no back-fill.

**The exit condition was never broken.** S289's `research-requirements` cycle ran
`3 → 4 → 7 → 0` and converged the moment the repair wave finally *cut* text. It is
reachable as soon as the reviewed scope holds still. S290's eight-pass
non-convergence is a **symptom of the ratchet**, not an independent defect — which is
why nothing here touches the exit condition, Check B, or the pass floor. Check D now
names the real remedy (*freeze the artifact, cut the added scope*) instead of "run
another pass," which is the advice that produced passes 2 through 8.

### What v0.51.0's rung actually did on this sprint: nothing yet

The over-engineering MAJOR rung is installed verbatim in the consumer and produced
**zero findings across all eight passes**. The tempting confirmation — *"every repair
subtracted, seven for seven"* — is confounded twice: S290's operator-set sprint theme
was literally **SUBTRACTION**, and v0.51.0's own changelog records that S289's
adversaries already removed by instinct *without* the rung. Reading the subtraction
result as the rung working would be a check that never fired, recorded as a check
that passed — the exact error class this release exists to end. **The rung is
therefore untouched in v0.52.0.** It needs another sprint of evidence, not another
edit.

### The stale remedy that would have deleted the ledger

`validate-artifact-budget.sh` told the lead to trim `pipeline-snapshot.md` to its
**6-section schema**. v0.50.0 had added `In-Flight Teammates` as the **seventh**
section and never swept the remedy text. A lead obeying it literally would have
deleted **the dispatch ledger that is the one thing demonstrably preventing
re-dispatch** — 0 of 28 on S290, against 13 of 39 on S289. The snapshot itself had
reached 66,782 bytes (**278% of budget**), whole-read at each of ten compactions in a
single day, while the sub-step budget check sat there reporting it: the check already
exited 1 past the grace band, and the step file said *"trim at your next natural
pause."* An obligation with no deadline is not an obligation.

## R33 — rationale purged from the agent-read path (v0.52.0)

*"Putting those things in the core skill are how we get agents 'reasoning' around the
rules and gates."* — operator, 2026-07-13.

A rule that explains itself invites negotiation. A gate that justifies its own design
hands the agent an argument for why the design does not apply *here*. And a pointer
from a gate file to this document is a **door**: the agent walks through it and comes
back with a story instead of a verdict.

v0.52.0 removed every rationale header, cross-doc pointer, measured anecdote, and
piece of version archaeology from the 38 agent-read files (`SKILL.md`, `steps/*.md`,
`core/team-roles/*.md`). Nothing was destroyed; it is all below. Shell scripts are out
of scope — their comments are read by maintainers, never by the pipeline.

### What was kept, and the test that decided it

**The test:** *can the agent use this sentence to argue the rule does not apply to
it?* If yes it is rationale — cut. If it is an invariant of the world — keep.

1. **Rule 26(c) contracts stay** (21 of them, verified intact). Rule 26(c) *requires*
   machinery to state the failure it catches, the false-positive cost, and its removal
   condition. That is a three-fact contract, not a rationale, and a retro audit flags
   machinery that lacks one — deleting them would break a different gate. They were
   compressed to the terse form, with the sprint-numbered measurements stripped out of
   the "failure caught" clause.
2. **Factual API/mechanism statements stay.** *"`Agent` returns an `agent_id`,
   `TaskOutput` takes a `task_id`"* is a fact an agent cannot argue with. v0.50.0 put
   it inline precisely so it would not be re-introduced.
3. **`gate-validation.md` H1 format examples stay** (`Sprint 288`, `Sprint S286`).
   Those are accepted-input strings for a parser, not anecdotes.

No `##`/`###` heading was deleted or renamed anywhere, so no consumer override was
orphaned (every graph `shadows:` entry anchors to a heading; all sites cut here were
bold/italic paragraph leads *inside* sections).

### The stories, relocated

**SKILL.md Rule 25(b) — the conditional whole-read exemption.** "Rely on (a) keeping
it bounded" was an assumption, not a mechanism: in the reference consumer
`product-brief.md` reached 480 KB (~120k tokens, 2× its budget) and
`carry-over-evaluation` whole-read it 11 times anyway, because nothing stood between
the exemption and the file. An exemption whose precondition is stated but never tested
is not an exemption; it is a hole.

**SKILL.md Rule 25(c) — logs named one at a time.** The flow log carried every event
of every sprint (1.3 MB / 5,418 events in the reference consumer) because "and similar
logs" bound it to nothing. `context-mode-protection-log.md` reached 210 KB in the same
consumer while appearing in NEITHER the (c) list nor the (d) threshold table —
unbounded, hook-written, and read at retro. Naming logs one at a time is how the gap
keeps recurring; (d) is what catches the next one.

**SKILL.md Rule 25(d) — why the clause used to say "warn-only, never blocks."** Every
budget fired at retro — at the end of the sprint that had already paid for the overage.
Artifacts ratcheted up, each sprint began slower than the last, and the only mechanism
that would have noticed always arrived after the cost. A ratchet with no pawl. In the
reference consumer this compounded until a single planning phase spent 3h16m, took six
auto-compactions, and never reached the architecture step.

**The grace band is aim, not softness.** A ratchet announces itself in *multiples* —
the reference consumer's real breaches were 161%, 215%, 526% and 3311% of budget. A
gate that also fails at 104% buys nothing and costs a lot: the lead trims 300 tokens,
the artifact grows back by the next gate, and it fails again. That treadmill turns a
real signal into noise, and a noisy gate gets ignored.

**Rule 29 — the bounded file-wait beat is the primary join.** In the reference
consumer's first three post-fix sprint sessions: 14 `Agent` spawns, 2 `TaskOutput`
attempts (both failed), **47 file-wait beats did all of the joining.**

**Rule 29 — the failure the beat replaces.** With no join named, the lead writes
`until [ -s "$d/s289-pm.md" ]; do sleep 20; done` as one `Bash` call. It runs to the
harness's 10-minute cap and returns `TIMEOUT` having produced nothing: ten minutes of
blind window bought for zero information. Six such calls in a single S289 planning
phase burned 52 minutes, 29 of them past the point of no return. The loop goes in the
beat count, never inside the call.

**Rule 29 — the steamroll count, and the miscount.** (b) was previously recorded as
111. It was 114 by the old count, of which 19 were the harness's own auto-compaction
resume prompt read as a human steer — the lead advancing after one is the recovery
protocol, not a steamroll. The filter now excludes them; the real figure is **95**. A
machine event miscounted as a human one is the recurring error class of this project.

**Rule 29 — Check C has caught nothing, and that is deliberate.** Across 278 consumer
sessions no lead has ever run even 3 consecutive bounded wait-beats — because until
this rule there was no reason to slice a poll at all; the observed failure is one
unbounded call, which Check A already catches. Check C bounds a shape *this rule
introduces*: once beats are the sanctioned way to wait, beating forever becomes the
natural way to hang. Shipping the ceiling unenforced was the alternative, and an
unenforced threshold is exactly the ratchet Rule 25(d) had to be rewritten to escape.

**Rule 29 — why Check D exists.** v0.44.0 wrote the rule around a join that cannot
join the thing ai-dlc actually spawns. The rule's headline mechanism was inert from the
day it shipped, and the bounded file-wait beat (added in v0.45.0 as a supposed
`Skill`-only special case) has been doing 100% of the real joining. A rule that names
the wrong API is worse than one that names none: it looks like guidance.

**`route.md` — why the artifact budget blocks at sprint start and nowhere else.**
Sprint start is the last moment at which an oversized artifact is cheap to fix — the
sprint has not read it yet. One step later, `carry-over-evaluation` whole-reads the
brief, the PRD, the architecture, and the backlog (Rule 25(b)), and every over-budget
byte is context that planning does not get back. Retro's audit of the same budgets
stays warn-only; it reports on a sprint that already paid.

**`_gate-procedures.md` — why the sub-step budget check is not gate-only.**
Implementation passes only three gates in a phase that can run four hours. A budget
enforced only at gates is unenforced for the longest, most dispatch-heavy step in the
pipeline.

**`gate-validation.md` Check 3a — why it is a gate-level check.** The story's own
validation cycle may pass (the story is internally coherent and its ACs are testable)
while the story still fails to address the thing it was created to address. That cannot
be caught by validating the story in isolation; it requires comparing the story to its
source.

**`gate-validation.md` Check 14 — the snapshot's cost.** In the reference consumer the
snapshot reached 50 KB (~15k tokens, 2.5× its 6k budget) and was whole-read 8 times in
one planning phase — the single largest byte-injector of any file in the session, and a
direct driver of the six auto-compactions that phase took.

**`gate-validation.md` Check 24 — why the four adversarial fields exist.** A verdict
the machinery cannot read is a verdict the lead adjudicates in prose: on S289 the
terminal pass reported 0 CRITICAL / 0 MAJOR, wrote "the repair wave converged," and
stamped `EXIT CONDITION NOT MET` — free text, in a key no script parsed, and the key
itself drifted mid-series (`exit_condition_met:` on pass 2, `verdict:` on passes 3–4).
The CRITICALs had run 3 → 4 → 7 across the three passes before it with no escalation,
and the §5 planning gate passed anyway.

**`gate-validation.md` H2 — the vacuous fixture.** H2 was not merely repetitive; it was
**vacuous**. All three `seed.sh` files were `echo` statements describing, in English,
fixtures that were never written to disk — so H2 read a *description of a test* and
adjudicated that. It could not fail, and it never did. Worse, `check-17-bypass`'s V5
carried `mode: solo`, which trips the Rule 20 solo assertion in
`validate-provenance-block.sh` *before* the SHA branch is reached: the forgery floor V5
exists to prove was never executed, while the fixture's README asserted it passed. Both
were fixed in v0.49.0 — the seeds write real files, `run.sh` asserts the matrix, and it
fails loudly with `the forgery floor is UNTESTED` if V5 regresses. Its cost was never
the problem: a check that runs 6 times and proves nothing is not expensive, it is
broken.

**`adversary.md` — why the verdict field exists.** v0.46.0 told the adversary a clean
verdict was a valid outcome and gave it nowhere to write one. On S289 pass 4 the
residue was 0 CRITICAL, 0 MAJOR, 2 MINOR; the prose said *"the repair wave converged …
I probed the repair hard and it holds"* — and the field said `verdict: EXIT CONDITION
NOT MET`, the same string pass 3 emitted. The lead read the prose, applied the two
one-line deletions, and passed the gate anyway. A review that converges in prose and
refuses to converge in its field has handed the decision back to the context whose
independence it exists to supply.

**`adversary.md` — why later passes review the repair.** On S289's
`research-requirements` cycle the CRITICALs per pass ran **3 → 4 → 7 → 0**, rising
every pass until the repair step finally *cut* text instead of adding it. Derivation:
`s289-rr-adversarial-pass1.md:180` (3), `pass2.md:252` (4), `pass3.md:517` (7),
`pass4-verification.md:492` (0). Pass 3's own summary: "Pass-2's repair wave injected
five new CRITICALs, three of them defects the repair itself created." The reviews were
not getting sharper; the repairs were manufacturing work. A role that must find
something will always find something, and the newest, least-defended text — the last
pass's repairs — is where it will look.

**`adversary.md` — the over-engineering rung, backtested.** On S289 an adversary filed
a "Rule 26 removal sweep" of three deletions (`s289-arch-adversarial-pass1.md:261-278`)
that its own `VERDICT: 2 CRITICAL, 1 MAJOR, 2 MINOR` counted **zero** of. Backtested
against all 21 S289 removal findings: the 8 filed MINOR are stale words and stale
counts, none names a mechanism, all 8 fail test 1, and the converged pass 4 (0 CRITICAL
/ 0 MAJOR / 2 MINOR) is unchanged.

## R34 — the adversarial cycle had no rung for "stuck" (v0.55.3)

S290's brief cycle ran **thirteen passes over ~12 hours** and did not converge. Passes
11, 12 and 13 each reported **0 CRITICAL and exactly 1 MAJOR**. Nothing fired, because
nothing could: the ladder had exactly two terminal states — CONVERGED (0/0) and
DIVERGENT (CRITICALs *rising*) — and a flat nonzero MAJOR at zero CRITICAL is neither.
It fell through to "run another pass", forever. Check D's own advice for that shape was
literally *"run another pass to a clean verdict"*, which is the instruction that
produced passes 11, 12 and 13.

**The generator was the repair step, and core already knew the failure mode.** Rule 8's
divergence text says, verbatim, *"These are defects the REPAIR injected into text that
had already been cleared."* But the predicate counts only CRITICALs, and only when
rising — so it was blind on both axes to what was actually happening. Every prior-scope
finding from pass 9 to pass 13 was a **false factual claim introduced by a repair**:

| pass | finding |
|---|---|
| p9  | A57 retracts pass 8's C2 on a FALSE absence claim |
| p9  | Story 3's seven cited "call sites" are not `get_symbol` call sites |
| p10 | A65's repair does NOT land at `:2530` |
| p10 | A67's *"the resolver never needs `pool_id`"* is FALSE |
| p11 | A70's item 4 is FALSE — three of seven DECIDES sites are wrong-pool |
| p12 | A72's stated premise is FALSE and contradicts A68 |
| p13 | a FOURTH wrong-pool site — falsifying the sentence p12 just wrote |

Fixing a finding meant writing a **new** claim about the code into the brief, and
nothing checked it until the next pass. Repairs injected defects at roughly the rate
review removed them, so MAJOR could not reach zero. The brief asserted *"all SEVEN
DECIDES sites are correct-pool"* and *"SEVENTEEN `"TEL"` compares"* — both false (a
fourth site; the true count is 16). Nobody ran the enumeration. The adversary ran it,
one counterexample per 40-minute pass, and was used as the verification oracle.

**Threshold, backtested.** Against every series the reference consumer has with severity
data (s289-rr, s289-teststrategy, s290-brief; six older series predate the v0.48.0
schema and carry no counts, so they can neither confirm nor deny): **K=2** fires on
s290-brief at pass 13 and false-fires nowhere — it never blocks a cycle that had already
stamped `EXIT_CONDITION_MET`. **K=3 fires nowhere in the entire corpus, including the
13-pass loop it exists to catch.** A rung that has never fired is indistinguishable from
no rung, so K=2.

**The ordering bug underneath it.** `order_key()` matched only `pass<N>`, but the
consumer names artifacts `-p<N>`. Every file in the 13-pass series keyed 999, the stable
sort preserved glob order — `1 10 11 12 13 2 3 …` — and Check D therefore read **p9** as
the terminal pass, not p13. It is dormant below ten passes and activates at ten: it
breaks in the long-cycle case it exists to police, and nowhere else. The old comment
claimed un-orderable files "are reported rather than silently folded into the chain."
No such report existed.

## R35 — repair was assigned to the one agent that could not do it (v0.56.0)

R34 diagnosed the endless adversarial cycle as **unverified repair authorship** and told the
lead to derive its repairs. That was the right constraint pointed at the wrong agent.

**The lead is the most context-saturated agent in the pipeline.** It orchestrates, dispatches
and compacts across the whole sprint. On S290 it **compacted 13 times** while authoring precise
claims about specific call sites and line numbers. It was not repairing from the document; it
was repairing from a lossy summary of a document it had last read many passes ago, and writing
that memory into the artifact as fact.

The asymmetry is total, and it is the whole argument:

| agent | context | record on the same facts |
|---|---|---|
| **lead** (repairs) | saturated, 13 compactions, orchestrating | **7 of 7 claims FALSE** (A57, A65, A67, A70, A72) |
| **adversary** (reviews) | fresh subagent, role-bound, reads source | **right every time** (re-derived by AST) |

Same task, same codebase, different context. **The context is the variable.** So "tell the lead
to be more careful" is an exhortation to the weakest agent in the system — the kind of fix that
reads well and does not hold. Repair is bounded, evidence-driven and code-reading: exactly the
shape that dispatches well. The adversary was already the proof, pointed the other way.

Core mandated the failure: `discovery.md` said the Rule 8 validation cycle is *"never
offloaded"*, and **no role owned repair**, so it fell to the orchestrator by default.

**The generalisable rule: when a task keeps going wrong, check WHICH AGENT owns it before adding
discipline to the agent that has it.** A role file is cheaper than an exhortation, and it is the
only one of the two that survives a compaction.

`remediator.md` is one dispatch per PASS (never per finding — the artifact is one document, and
parallel editors produce a document that contradicts itself). The prohibition was SPLIT, not
deleted: authoring still needs whole-document intent and stays inline; the lead keeps dispatch,
the join, and the Rule 11/13 scope calls, which are decisions rather than edits.

## R36 — the hard block that had no exit (v0.59.0)

**Why this is a notes entry and not inline prose.** Rule 8's resident text carries the four
verbs and nothing else; SKILL.md's re-attach budget had **12 tokens of slack** after this
release, and the payment for adding the resume contract was deleting Rule 8's enumeration of
the per-intensity skips — a list that restated what each step file already enforces and that
the lead never acted on. Resident text that changes no behaviour is the first thing to cut.

**The shape of the bug, because it will recur in a different costume.** Two mechanisms
adjudicated the same event and gave opposite orders: the Stop hook's deny reason said *"do NOT
dispatch another adversarial pass, and do NOT clear the pause flag"*, while Check 24 arm D
said *"resolve the divergence … then re-run the cycle to a clean pass."* The gate required the
pass the hook forbade. Neither named the state between them.

The generalisation: **an enforcer with no sanctioned release is a deadlock.** v0.57.0 was
built on the true observation that *a verdict with no enforcer is a suggestion*, and it fixed
that — and then shipped the dual of the same mistake in one sentence of prose. When you give a
signal teeth, write down what makes the teeth let go, in the same change. If you cannot name
the release condition, you have not finished designing the block.

Its tell was visible in the code and nobody looked: the hook's own comment said *"The operator
clearing the flag IS the adjudication, and this must not fight it"* — three lines above the
message forbidding exactly that. **The agent reads the message, not the comment.**

**`FREEZE_SCOPE` could never have worked, and that is a class of bug, not an incident.**
`DIVERGENT_HARD_BLOCK` fires only when prior-scope CRITICALs rise — CRITICALs in text that is
*already frozen*. Freezing it again removes nothing. The lead offered freeze as its starred
recommendation, the operator authorized it in those words, and it was void the moment it was
uttered. Nobody noticed for a day, because **an option that cannot succeed looks exactly like
an option that has not been tried yet** — the same shape as *a check that cannot fire reads
exactly like a check that passed*, moved from the validator into the decision space. When you
enumerate choices for an operator, ask of each one: *what would make this fail?* An answer of
"nothing, by construction" means it is not a choice.

**Where the teeth go.** `Stop` fires only when the lead YIELDS, and Rule 3 plus the continue
hook exist to make it never yield. v0.57.0's enforcer therefore fired **by luck**. Any check
that must prevent an action belongs in `PreToolUse`, where the action can be denied; `Stop` is
for surfacing to a human, not for enforcement. This is worth a standing rule: *if the failure
mode is "the lead does X", the guard must run before X, not after the turn in which X happened.*

**On the honest ceiling of a gate.** Two of the four resolution kinds close mechanically
(`REVERT_REPAIR` against notarized shas; `CUT_SCOPE` against bytes). Two do not, and cannot:
"I changed the approach" is a claim about intent with no byte-level predicate. The design says
so out loud, demands the operator's words verbatim, and **counts** them, with a tightening
condition stated in advance. Pretending otherwise would have produced a check that cannot fire.
A global *"the artifact must SHRINK"* rule was rejected for the opposite reason: it is a
**deletion incentive**, and a gate that rewards deleting load-bearing spec to pass is worse
than the bug it polices (v0.56.x, exactly).

**And the one that indicts the process.** v0.57.0's CHANGELOG told the reference consumer to
revert pass 16's repair. Pass 16's repair was **correct** — pass 17 says so in terms — and the
revert would have restored the zero-as-sentinel defect the sprint existed to kill. That
paragraph was written from a confident reading of a transcript, in a release whose whole
subject is a repair step that authors false claims, and it was never run against the artifacts.
It is retracted in place in the changelog rather than quietly edited. **A detailed, confident
account of what went wrong is a hypothesis. The control test is cheap. Run it.**

## R37 — the beat quantum was a foreground bound on a backgrounded wait (v0.167.0)

The question that started this: every wait-beat costs the lead a turn, and now that
subagent tracking is accurate (`spawn-ledger.jsonl` at dispatch, `subagent-context.jsonl`
at `SubagentStop`), could the beat be replaced by completion signalling — a monitored
output file, or the harness's own task-notification?

Measured first, on the reference consumer's s298:

| | |
|---|---|
| `ALLOWED_BY_LIVE_BEAT` events (lead turns ended inside a join) | **131** |
| total armed wait | 4h04m |
| beat length | p50 117s, max 119s |
| worst single dispatch (`dev-escalated-s298-1`, 62 min) | **31 beats** |
| prior sprints | 109 / 260 / 231 |
| `.wait-beats` residue | 52 counters; **32 delivered on beat 1**; max 7 |

### The beat is not a polling cost

`wait-for-deliverable.sh` already breaks its loop the instant every joined path has
landed (`all_present()`), so a delivery re-invokes the lead within one `POLL` — ten
seconds. A completion signal cannot beat that. 32 of 52 counters show delivery on the
first beat. **Every wasted turn is a beat that timed out with work still outstanding**,
which makes the whole cost a function of the quantum and nothing else. The mental model
that had to go was "the beat polls, therefore the beat is the cost."

### Completion signalling was measured and REJECTED

Three findings, all from s298, all fatal to a wake driven by `SubagentStop`:

1. **A stop is not terminal.** `subagent-context.jsonl` holds 83 records for ~7
   dispatches — agents appear ×2, ×3, ×4. An agent that stops can be resumed.
2. **A stop is not a delivery.** One agent emitted three stop records (22:17, 22:20,
   22:30) while its deliverable was still absent and the lead was correctly still
   beating. A wake keyed on stop would have fired three false completions.
3. **The probe is allowed to record nothing.** `ai-dlc-subagent-probe.sh` exits 0
   silently on absent `jq`, an unreadable transcript, or a missing snapshot — correctly,
   since it must never block a subagent. But a Stop-hook allow computed as "ledger minus
   completions" would then never decrement, and the lead would yield with nothing
   scheduled to re-invoke it. That is the one dead-pipeline case Rule 29 names, reached
   through the bookkeeping rather than through the join.

A separate observation makes the same point from the other side: the lead once
`TaskStop`'d `gate-adjudicator-s298-impl-3` and recorded that it "produced no verdict
file". The file existed, 22,772 B, written four minutes *earlier*. The lead asserted an
absence it never checked. Whatever wakes the lead, **the file is still the only thing
that can be believed**, and the beat's mtime predicate stays exactly as it was.

### What was actually wrong: one env var, two meanings

`AI_DLC_STEERING_BUDGET` was read by both `validate-steering-budget.sh` (Check A: the
maximum a **foreground** call may block, because a queued operator message cannot land
while one is in flight) and `wait-for-deliverable.sh` (how long a beat may sleep). Since
v0.81.0 the beat is **backgrounded** and the lead has ended its turn, so it gags nobody
and a queued operator lands on the very next turn regardless. The 120s cap was a
foreground-gag bound still clamped onto a mechanism that stopped being foreground two
years of releases ago — and its only remaining effect was to re-invoke the lead every two
minutes for the life of every long join.

The validator's own code already knew. Check A skips `u.bg`; `isWaitBeat` requires
`run_in_background !== true`; and `fixtures/check-25-steering-conduct/` carries a decoy
case — "a 30-min call with `run_in_background: true` → **0** violations" — whose README
says flagging it "would punish the exact dispatch shape Rule 29 *prescribes*". Three
independent statements that the backgrounded beat was never bound by the steering budget,
and the script read the variable anyway. **A shared name is a shared constraint whether or
not anyone intended one.**

Split: `AI_DLC_WAIT_BEAT_SECS` (600) governs the beat; `AI_DLC_STEERING_BUDGET` (120)
stays foreground-only. s298 replay: 131 beat-turns → ~30.

### The ceiling was separately wrong, and had already cost something

`max_wait_beats × quantum` was 20 minutes. S297 declared `adversary-p1-rr` non-delivered
at that ceiling and re-dispatched — a live teammate, duplicated work, the exact
false-NON-DELIVERY the script's own counter comments warn about. s298 then ran a
legitimate **62-minute** dispatch. The bound was tuned to a beat quantum rather than to
what teammates take. `max_wait_beats` 10 → 6 puts the ceiling at 60 minutes.

### Two guards, without which the larger quantum would have been a regression

**The marker had to become a lease.** `.beat-inflight` held the beat's worst-case end
epoch, written once. Stop-hook Check 2b authorizes the lead's yield while that epoch is in
the future. A SIGKILLed beat skips its `EXIT` trap, so the authorization stood for the
whole remaining quantum with nothing alive to re-invoke the lead — a dead window sized
*exactly* to the quantum. At 120s that was survivable; multiplying it by five would not
have been. The loop now re-stamps the marker every poll with `now + 3*POLL`, so a dead
beat's lease expires in ~30s no matter how large the quantum grows. The hook is unchanged:
`epoch > now` reads a lease exactly as it read a promise. **When you widen a bound, look
for what was silently sized by it.**

**The counters had to be scoped to their bound.** `.wait-beats/<key>` counters survive a
pull. A consumer mid-join carrying a count of 7 against the old ceiling of 10 would have
exhausted on its *first* beat under the new ceiling of 6 — shipping the retune would have
manufactured the very false non-delivery the retune exists to prevent. The counter dir now
records the active bound in `.bound` and wipes itself once whenever it changes. The
fixture pair that pins this is one byte apart: `exhausted` seeds `.bound=6` and must
exhaust, `counter-bound-reset` seeds `.bound=10` and must not. Deleting the self-heal reds
only the second; a self-heal that wiped unconditionally would red only the first.

### What the fixtures had to prove, and how

A merged knob is invisible in operation — both readings are "a number of seconds" — so it
is asserted from both directions. `knob-split-forward` (quantum 3s, budget 30s → must
return fast) catches the budget winning; `knob-split-reverse` (quantum 8s, budget 3s →
must sleep) catches an alias in the other direction, which the forward case alone would
miss whenever the budget happened to be smaller. Verified by mutation: re-merging the
variables reds **both** knob cases and **no** pre-existing case — which is the proof they
carry the whole assertion rather than riding on coverage that already existed.

### Left open, deliberately

The lead still cannot distinguish a stalled teammate from a working one without reading
its transcript — `CO-S290-SUBAGENT-BACKGROUND-YIELD-STRANDS`, closed WONTFIX at S297 with
bounded-join beats named as the accepted mitigation. The material for a real fix now
exists: a beat could read `subagent-context.jsonl` and, on a `WAITING` path whose agent
has already emitted stop records, say so. It would have to be **advisory** — finding (1)
above means a stop is not proof of death, and an automatic verdict there would re-dispatch
live teammates, which is the failure this whole mechanism exists to prevent. Not shipped
here. The carry-over stays open, and nothing in this release should be read as closing it.
