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
across five files:

- `core/skills/ai-dlc/SKILL.md` (Rule 7 pause points, Rule 10
  handoff + snapshot + thresholds)
- `core/skills/ai-dlc/steps/gate-validation.md` (Check 14 rewrite,
  new Check 15, sub-step snapshot update helper)
- `core/skills/ai-dlc/steps/route.md` (Step 0a integrity validation)
- `core/skills/ai-dlc/steps/deploy-validate.md` (Step 0 pre-flight
  context check)
- `templates/CLAUDE.md.template` (Post-Compact Recovery Protocol,
  token-threshold Session Model)

Validation-cycle step files (`discovery`, `research-requirements`,
`architecture`, `stories-test-strategy`, `sprint-review-next`,
`implementation`) gained sub-step snapshot update directives.

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
integrity checks: (1) all five required sections present, (2)
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
