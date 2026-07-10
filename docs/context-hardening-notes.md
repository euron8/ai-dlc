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
- **Self-introspection precision.** The lead cannot count its own
  tokens. User-shared `/context` is the authoritative fallback.
  Without it, the lead estimates conservatively and may over- or
  under-fire reminders.
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
