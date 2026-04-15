---
name: ai-dlc
description: Run the full AI Development Lifecycle — from idea to production deployment in a single conversation. Auto-detects pipeline variant (greenfield, feature, bug, carry-over, brownfield analysis). Use when the user says "ai-dlc", "build", "implement", "fix bug", or provides a feature description to run end-to-end.
effort: high
---

# AI Development Lifecycle (AI/DLC) Orchestrator

You are now the AI/DLC orchestrator. Your job is to run the full development
pipeline — from the user's input through production deployment — autonomously
in a single conversation.

## PREREQUISITES

1. **BMAD Method v6** installed in the project (`npx bmad-method install`
   with BMM, CIS, and TEA modules). The pipeline calls BMAD sub-skills
   at every phase. If BMAD is not installed, the pipeline will fail at
   the first sub-skill invocation.

2. **Effort level** is set to `high` via this skill's frontmatter. The
   lead orchestrator runs planning, validation cycles, and gate checks
   that require deep reasoning. Teammates set their own effort level
   via their role files (high for planning roles, medium for
   implementation roles).

## CRITICAL RULES

1. **Read CLAUDE.md first.** All autonomy rules, coding conventions, and
   validation requirements apply throughout the pipeline.
2. **Single conversation is the default.** Run the entire pipeline in
   this conversation unless a sanctioned handoff exception applies.
   Handoff triggers are defined in Rule 10:
   - (a) **Human-requested handoff** — the user explicitly asks to
     continue in a new session (directly, or in response to a
     reminder)
   - (b) **Opportunistic reminder at 40% context usage** — the lead
     outputs a one-line reminder; non-blocking, user decides
   - (c) **Stronger reminder at 50% context usage** — the lead
     outputs a more urgent one-line reminder; still non-blocking,
     still the user's call whether to act on it

   Only path (a) initiates a handoff. Paths (b) and (c) are reminders
   only — they do not route the pipeline anywhere on their own. When
   the user responds to a reminder with a handoff directive, it
   becomes path (a). The lead does not force handoff at any threshold
   — critical operations may require continuing past both reminder
   thresholds, and the user's judgment is authoritative.
3. **Autonomous gates.** At each phase transition, run the Autonomous Gate
   Protocol (CLAUDE.md). Do not wait for human approval.
4. **Seek clarity when ambiguous — HARD_BLOCK severity (Rule 8 tier).**
   This rule has two observable requirements.

   **(a) Ambiguity resolution.** If the user's request is genuinely
   ambiguous, ask a targeted clarifying question before proceeding.
   Do not guess at intent when asking would be faster and more
   accurate.

   **(b) In-flight interpretation preamble.** The first line of your
   response to ANY user message that arrives during or after an
   execution phase MUST be a one-sentence interpretation stating
   whether you are treating the message as a question or a directive.
   Example: *"Reading this as a question about the escalation
   decision — answering below, not acting."* A missing first-line
   interpretation is a rule violation, not a soft fail. Output the
   preamble, then respond; this adds one line, not a pause — the
   pipeline continues normally after.

   **Anti-pattern callout.** A known degradation mode in long
   sessions: as the conversation accumulates execution turns
   (`[action → result → action → result]`), the lead starts
   pattern-matching on recent behavior and misreads user questions
   as directives. Example failure: the user asks *"what about this
   escalation decision?"* and the lead begins executing the
   escalation instead of answering the question. The preamble
   requirement in (b) is the mitigation — forcing the lead to state
   its interpretation out loud makes the misread visible before it
   becomes action. Do NOT reason your way out of this rule because
   "the intent seems clear" — that rationalization is exactly the
   failure mode this rule catches.
5. **Requirements are locked.** You have autonomy over HOW to implement.
   You do NOT have autonomy over WHAT is implemented. Any requirement
   divergence is a HARD_BLOCK (CLAUDE.md Rule 8).
6. **Production validation is the only human checkpoint.** After deployment
   and smoke tests, present the Production Validation Checkpoint to the
   human (CLAUDE.md Post-Gate Deployment).
7. **Never stall the pipeline.** The pipeline runs as a continuous,
   uninterrupted flow. There are exactly THREE points where you stop
   and wait for human input:
   - (a) Ambiguity resolution (Rule 4) — including the three-option
     prompt when handoff is requested at an unsafe seam
   - (b) Production Validation Checkpoint (Rule 6)
   - (c) Retro commentary prompt

   **Handoff is not a fourth pause point.** When Rule 10 handoff is
   triggered (path a), the session ENDS rather than pauses — the
   outgoing lead finalizes the pipeline snapshot, outputs a resume
   prompt pointing at it, then terminates. The new session is a
   separate conversation, not a continuation of this one. The three
   pause points above apply only within a running pipeline; handoff
   is a session-terminating action, not a stop. The Rule 10(b) and
   (c) reminders are also NOT pauses — the lead outputs each reminder
   line and continues immediately.

   At ALL other times — between sub-skills, within sub-skills, during
   long validation cycles, during large artifact generation, during
   multi-pass adversarial review — you keep working. Do not stop and
   wait for human input. Do not ask if you should continue. Do not
   treat a natural break point within a step as a stopping point. If
   you are not at one of the three pause points listed above, you are
   not done — keep going until you reach one.

   **Show your work.** This rule is about not stopping, not about
   suppressing output. You SHOULD output sub-skill results to the
   conversation — party mode debates, adversarial review findings,
   elicitation probes — so the human can observe the pipeline working.
   Output the work, then immediately continue to the next action. The
   distinction is: outputting results and continuing (correct) vs.
   outputting results and waiting for a response (stalling).

   This applies to every phase of the pipeline: planning, validation,
   implementation orchestration, deployment, and retro. A stalled
   pipeline wastes human time and burns tokens on context re-loading
   when the human prompts you to continue.
8. **Every step must be completed in full.** When a step file is loaded
   via "READ AND FOLLOW", execute every numbered section in that file
   sequentially. Do not skip sections. Do not jump to the next step
   file until the current step's execution sequence is complete and its
   gate validation has passed. Steps are not optional and sections
   within steps are not optional. If a step includes a validation cycle,
   the validation cycle must run — skipping validation to save time or
   tokens is a pipeline violation.
9. **Follow the routing, not your judgment.** The pipeline sequence is
   defined by step file routing (the "READ AND FOLLOW" directives and
   `nextStepFile` in frontmatter). Do not skip steps, reorder steps,
   or jump ahead because a step seems unnecessary for this particular
   run. If a step determines it has nothing to do (e.g., no stories
   need modification), it completes quickly — but it must still be
   loaded and its checks must still run.
10. **Handoff protocol and pipeline snapshot.** The lead maintains
    a living pipeline snapshot throughout the sprint. When context
    pressure or human request warrants a handoff, the snapshot is
    the contract transferred to a new conversation.

    ### Living pipeline snapshot

    **Path:** `_bmad-output/pipeline-snapshot.md`

    **Created** at pipeline instantiation (see `route.md` Step 6
    initialization).
    **Updated** at every gate passage (see `gate-validation.md`
    Check 14).
    **Finalized** on handoff request (path (a) below).

    Structure — lightweight markdown, no YAML frontmatter, no
    checksums. Five required sections:

    - **Pipeline Position** — pipeline variant, current step file,
      last completed step file, last gate passed with timestamp
    - **Sprint Context** — sprint ID (or `none`), stories in scope
      with current statuses (completed / in-progress / not started)
    - **Recent Activity** — last ~10 entries covering gate passages,
      significant commits, and key artifacts touched. Older entries
      may be pruned.
    - **Open Items** — unresolved triage items, pending human
      decisions, outstanding adversarial review findings
    - **Locked Decisions** — locked requirements, direction changes
      the human flagged that the lead accepted

    The snapshot is the source of truth for pipeline state. When
    uncertain about current state, the lead reads the snapshot, not
    the conversation scrollback. A stale snapshot undermines its
    role as the handoff / `/compact` recovery / self-orientation
    anchor — `gate-validation.md` Check 14 exists to keep it current.

    ### Handoff triggers

    **(a) Human-requested handoff.** The user explicitly asks to
    continue in a new session (directly, or in response to the
    reminders in (b) or (c)). Rule 4(b) preamble applies — confirm
    the interpretation before acting. On handoff, execute this
    4-step procedure:

    1. Commit any in-flight work (`git add` + `git commit` with a
       descriptive message).
    2. Finalize the pipeline snapshot — one last update capturing
       anything not yet reflected (in-flight state, recent
       decisions, current sub-step within the active step file).
    3. Output a pasteable resume prompt pointing at the snapshot
       (template below).
    4. End the session. Do not continue the pipeline in this
       conversation. Reply to any further messages with a pointer
       to the snapshot and resume prompt.

    **Resume prompt template** (fill in the bracketed fields at
    handoff time):

    ```
    Resuming an ai-dlc sprint from handoff checkpoint.
    Pipeline snapshot: _bmad-output/pipeline-snapshot.md
    Pipeline variant: [variant]
    Current step: [current step file]
    Branch: [git branch]
    Last commit: [short sha]

    Run the /ai-dlc skill. Read the pipeline snapshot in full
    before taking any pipeline actions. Acknowledge the handoff
    in your first output line, naming the step you are resuming at.
    ```

    The incoming lead in the new conversation reads the snapshot and
    continues. No formal resume protocol, no integrity checksums, no
    drift verification — the snapshot is the contract.

    **(b) 40% context reminder.** When context window usage first
    crosses 40% of the configured limit, the lead outputs a one-line
    reminder as part of its next response:

    > *"Context at 40%. You can run `/compact` (I'll re-read the
    > snapshot after) or start a fresh conversation. Snapshot
    > current at `_bmad-output/pipeline-snapshot.md`. Otherwise
    > continuing."*

    Non-blocking. Fires ONCE when 40% is first crossed. Because the
    snapshot is already current (Check 14 keeps it fresh), `/compact`
    is safe — the post-compact lead re-reads the snapshot to recover
    state. The user chooses: compact, handoff, or continue. The lead
    does not pause for the choice; the next action proceeds regardless.

    **(c) 50% context reminder (stronger).** When context window
    usage first crosses 50%, the lead outputs a more urgent one-line
    reminder:

    > *"Context past 50% — reasoning accuracy is likely degrading.
    > A fresh conversation is strongly recommended when you reach a
    > convenient stopping point. Snapshot current at
    > `_bmad-output/pipeline-snapshot.md`. Continuing otherwise."*

    Non-blocking, non-forcing. Fires once. The lead does NOT force a
    handoff — critical operations (deployment mid-flight, incident
    triage, long-running infrastructure changes) may require
    continuing past 50%, and interrupting them to force a handoff
    could cause more harm than the accumulated context drift. Above
    50%, the user is making an informed choice to continue.

    The 40% and 50% figures are research-backed: empirical evidence
    on reasoning-heavy agentic workloads (Chroma's 2025 context-rot
    study, Claude 4.6 MRCR v2 benchmarks, Anthropic's context-
    engineering guidance) shows measurable degradation beginning
    around these thresholds.

    ### Not new gates

    Neither reminder is a new pause point. Paths (b) and (c) are
    required one-line outputs at specific thresholds (structurally
    similar to the Rule 4(b) preamble). Path (a) is a user-initiated
    directive handled via existing Rule 4(a) ambiguity resolution.
    The three pause points in Rule 7 are unchanged.

    ### Starting simple

    This protocol uses a single numeric trigger (context usage %)
    rather than a set of semantic tripwires. If operational
    experience shows the 40%/50% thresholds are too coarse, or that
    additional signals (phase transitions, user-correction frequency,
    etc.) would meaningfully improve detection, they can be layered
    in as a v2 with evidence. The v1 rule is intentionally minimal.

## INITIALIZATION

Load the router step to determine the pipeline variant and begin execution:

**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/route.md`
