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
   - (b) **Yellow-threshold reminder (first token threshold crossed)**
     — the lead outputs a one-line reminder with routing options;
     non-blocking, user decides
   - (c) **Red-threshold reminder (degradation-zone token threshold
     crossed)** — the lead outputs a more urgent one-line reminder;
     still non-blocking, still the user's call whether to act on it

   Only path (a) initiates a handoff. Paths (b) and (c) are reminders
   only — they do not route the pipeline anywhere on their own. When
   the user responds to a reminder with a handoff directive, it
   becomes path (a). The lead does not force handoff at any threshold
   — critical operations may require continuing past both reminder
   thresholds, and the user's judgment is authoritative. Thresholds
   are model-aware absolute token counts defined in Rule 10; they
   are not percentages.
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

   Post-compact recovery outputs a verification turn for user
   transparency (see CLAUDE.md "Post-Compact Recovery Protocol")
   but MUST NOT pause the pipeline. The lead outputs the
   verification turn content and proceeds to the next pipeline
   action in the same response. The user MAY interrupt on the
   next turn to correct mismatched state or request handoff.

   **Handoff is not a fourth pause point.** When Rule 10 handoff is
   triggered (path a), the session ENDS rather than pauses — the
   outgoing lead finalizes the pipeline snapshot, outputs a resume
   prompt pointing at it, then terminates. The new session is a
   separate conversation, not a continuation of this one. The three
   pause points above apply only within a running pipeline; handoff
   is a session-terminating action, not a stop. The Rule 10(b) and
   (c) reminders are also NOT pauses — the lead outputs each reminder
   line and continues immediately. A user reply to a reminder is a
   separate directive handled per Rule 4, which may request handoff
   (path a) or correct course (still within path a semantics); the
   reminder line itself never pauses the pipeline.

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
    **Updated** at every gate passage (full refresh, see
    `gate-validation.md` Check 14) and at sub-step boundaries
    within validation cycles and during implementation (lightweight
    Recent-Activity + Open-Items refresh, see `gate-validation.md`
    "Sub-step snapshot update").
    **Verified** after each gate-level update by
    `gate-validation.md` Check 15, and on resume by `route.md`
    Step 0a.
    **Finalized** on handoff request (path (a) below).

    Structure — lightweight markdown, no YAML frontmatter, no
    checksums. Six required sections:

    - **Pipeline Position** — pipeline variant, current step file,
      last completed step file, last gate passed with timestamp,
      current git branch (captured at initialization and refreshed at
      each gate passage so `route.md` Step 0a can verify branch match
      on resume)
    - **Sprint Context** — sprint ID (or `none`), stories in scope
      with current statuses (completed / in-progress / not started),
      `is_ui_epic` boolean (set by `stories-test-strategy.md` Step 7;
      read by `deploy-validate.md` for visual verification gating)
    - **Recent Activity** — last ~10 entries covering gate passages,
      significant commits, and key artifacts touched. Older entries
      may be pruned.
    - **Open Items** — unresolved triage items, pending human
      decisions, outstanding adversarial review findings
    - **Locked Decisions** — locked requirements, direction changes
      the human flagged that the lead accepted
    - **Context Reminders** — records which threshold reminders
      have already been output this session and supports recurring
      reminders past threshold. Required fields:
      - `context_reminders_sent: none | yellow | red` — highest
        threshold crossed so far. Initialized to `none`.
      - `last_yellow_fire_tokens: <integer or null>` — token count
        at last yellow reminder fire, or `null` if not yet fired.
      - `last_yellow_fire_turns: <integer or null>` — turn count
        at last yellow reminder fire, or `null`.
      - `last_red_fire_tokens: <integer or null>` — token count at
        last red reminder fire, or `null`.
      - `last_red_fire_turns: <integer or null>` — turn count at
        last red reminder fire, or `null`.

      Updated by `gate-validation.md` Check 14 whenever a threshold
      is crossed or a recurring reminder fires. The field exists so
      Check 14 can determine whether to emit a reminder without
      relying on conversation scrollback.

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
    continues. Resume integrity checks are enforced by `route.md`
    Step 0 and the post-compact verification turn defined in
    CLAUDE.md "Post-Compact Recovery Protocol" — the snapshot is
    the contract, and those two mechanisms validate it before action.

    ### Post-compact recovery (cross-reference)

    The authoritative post-compact recovery directive lives in
    CLAUDE.md "Post-Compact Recovery Protocol" (placed there so it
    survives compaction). On any `/compact` or auto-compact event,
    the lead reads the snapshot in full, outputs the recovery
    acknowledgment line, outputs the verification turn content
    (current step file, last gate with timestamp, any in-flight
    sub-step, current git branch and last commit), and proceeds
    immediately to the next pipeline action in the same response.
    The verification turn is not a pause point. Do not duplicate
    the directive here; the CLAUDE.md section governs.

    **Threshold defaults (model-aware, absolute token counts).**

    | Model context window | Yellow (first reminder) | Red (urgent reminder) |
    |---|---|---|
    | 200K | 80K tokens | 120K tokens |
    | 1M   | 120K tokens | 200K tokens |

    These are defaults. A project's CLAUDE.md may override them in
    the `{context_thresholds}` block (populated by `/ai-dlc-setup`
    from the selected model strategy — full vs. sonnet-only affects
    which context-window row applies). Percentages are not used;
    the same percentage across different models produces different
    token counts, and research-observed degradation is tied to
    absolute tokens, not fraction-of-window.

    **Introspection — user is source of truth.** The lead cannot
    reliably self-measure its own context window. The user is the
    source of truth for context usage. The lead MAY invite the user
    to share `/context` output at any point and MUST treat the most
    recent user-shared `/context` as the authoritative trigger for
    the threshold evaluations in (b) and (c). When no user-shared
    `/context` is available, the lead falls back to a conservative
    turn-and-tool-output estimate that errs high. This replaces any
    implicit assumption that the lead can detect threshold crossings
    on its own. See the CLAUDE.md Session Model "Context
    introspection" bullet.

    **(b) Yellow-threshold reminder.** When conversation context
    first crosses the yellow threshold configured for the active
    model, the lead outputs this line as part of its next response
    (substituting the actual threshold value):

    > *"Context at {yellow_threshold}+ tokens. Options: (1) new
    > session via handoff, recommended before any upcoming gate or
    > deployment; (2) `/compact` with instruction 'preserve
    > pipeline-snapshot.md reference and current step file',
    > acceptable only mid-step; (3) continue, acceptable if wrapping
    > up current sub-step soon. Snapshot current at
    > `_bmad-output/pipeline-snapshot.md`."*

    The three options are routed rather than equivalent: handoff is
    the default recommendation before any gate or deployment;
    `/compact` is acceptable only mid-step; continuing is acceptable
    only if the current sub-step is about to wrap. The lead outputs
    the line and continues immediately — the reminder does not pause
    the pipeline. Any user reply is a Rule 4 directive.

    **Recurrence.** The yellow reminder fires on the first crossing,
    then re-fires every additional 50,000 tokens past the yellow
    threshold OR every 20 turns past the first fire, whichever
    comes first. A single early reminder is not sufficient for long
    sessions. `gate-validation.md` Check 14 implements the
    recurrence using the `last_yellow_fire_tokens` and
    `last_yellow_fire_turns` snapshot fields.

    **(c) Red-threshold reminder (urgent).** When conversation context
    first crosses the red threshold configured for the active model,
    the lead outputs this line (substituting the actual threshold
    value):

    > *"Context past {red_threshold} tokens. Research-observed
    > reasoning degradation is likely present. Strongly recommend
    > new session via handoff at the next sub-step boundary. Avoid
    > `/compact` before any gate, deployment, or adversarial review.
    > Snapshot current at `_bmad-output/pipeline-snapshot.md`.
    > Continuing otherwise."*

    Still non-blocking. The lead does NOT force a handoff — critical
    operations (deployment mid-flight, incident triage, long-running
    infrastructure changes) may require continuing past the red
    threshold, and interrupting them to force a handoff could cause
    more harm than the accumulated context drift. Past the red
    threshold, the user is making an informed choice to continue;
    the lead's role is to make the risk visible.

    **Recurrence.** The red reminder fires on the first crossing,
    then re-fires every additional 50,000 tokens past the red
    threshold OR every 20 turns past the first fire, whichever
    comes first. `gate-validation.md` Check 14 implements the
    recurrence using the `last_red_fire_tokens` and
    `last_red_fire_turns` snapshot fields.

    The token thresholds are research-backed: empirical evidence on
    reasoning-heavy agentic workloads (Chroma Hong et al. 2025
    context-rot study, Claude Code empirical observation of
    degradation around ~147K tokens in a 200K window, Anthropic
    context-engineering guidance) shows measurable degradation tied
    to absolute token count rather than fraction-of-window. See the
    footnote at the end of this rule for citation details.

    ### Auto-handoff (configurable, `auto_handoff_mode`)

    The lead MAY automatically execute the path (a) 4-step procedure
    at defined safe seams when all preconditions hold. The
    authoritative configuration, mode semantics, precondition list,
    and distinguishing output line live in CLAUDE.md Session Model
    "Auto-handoff mode". The shared precondition helper and seam
    call contract live in `gate-validation.md` "Auto-handoff
    evaluation".

    Binding constraints:

    - Auto-handoff MUST NOT fire under `auto_handoff_mode: off`.
    - Auto-handoff MUST NOT fire off a Mode 2 fallback estimate.
      Only Mode 1 (user-shared `/context`) advances
      `context_reminders_sent` to `red`, which is the precondition
      the helper reads. This is an absolute constraint — Mode 2
      estimates are advisory only.
    - Auto-handoff is NOT a fourth pause point. It is a
      session-terminating action that executes the path (a)
      procedure unchanged. The three pause points in Rule 7 remain
      the complete set.
    - Auto-handoff output MUST be distinguishable from a
      human-requested handoff: the lead outputs the auto-handoff
      line naming the mode, seam, and confirmed token count
      immediately before the resume prompt.
    - Resume itself is NOT automated. The user MUST open a new
      conversation and paste the resume prompt.

    ### Reminders are non-blocking output, not pause points

    Paths (b) and (c) produce required one-line outputs at specific
    thresholds (structurally similar to the Rule 4(b) preamble). The
    lead outputs the reminder line and the next action proceeds
    immediately — the reminder itself never pauses the pipeline.

    Any user response to a reminder is a separate user turn and is
    handled per Rule 4: it is a directive, and the user's judgment
    is authoritative. If the response requests handoff, route to
    path (a). If the response requests `/compact`, acknowledge and
    continue (the lead has no control over the compact event
    itself). If the response says "continue", no action is required
    because the pipeline has already continued. There is no
    contradiction between "non-blocking output" and "user authority":
    the reminder line is output; the user's reply is a directive.

    Path (a) handoff requests (direct or in reply to a reminder) are
    user-initiated directives handled via existing Rule 4(a)
    ambiguity resolution. The three pause points in Rule 7 —
    (a) ambiguity, (b) production validation, (c) retro — are the
    complete set.

    ### Starting simple

    This protocol uses absolute token thresholds (two per model
    context window) rather than a set of semantic tripwires. If
    operational experience shows the yellow/red thresholds are too
    coarse, or that additional signals (phase transitions, user-
    correction frequency, etc.) would meaningfully improve detection,
    they can be layered in as a v2 with evidence. The v1 rule is
    intentionally minimal.

    ### Research citations (footnote)

    The token thresholds and the "absolute tokens, not percentages"
    framing come from these sources. A future maintainer must be
    able to re-check the thresholds against primary research before
    changing them.

    1. **Chroma Hong et al. 2025, "Context Rot" technical report.**
       Empirical evidence that LLM reasoning accuracy declines with
       absolute input length on multi-hop and needle-in-haystack
       tasks, with degradation measurable well before the nominal
       context window limit. Supports: (i) use of absolute token
       thresholds rather than fraction-of-window, (ii) the general
       shape of a yellow/red two-stage alerting model with the
       first inflection in the tens-of-thousands-of-tokens range.

    2. **Claude Code empirical observation.** On reasoning-heavy
       agentic workloads in a 200K context window, practitioners
       report observable degradation beginning around ~147K input
       tokens (roughly 70–75% of nominal). Supports: (i) the red
       threshold at 120K tokens for 200K models (first-order warning
       zone rather than catastrophe zone), (ii) the yellow threshold
       at 80K tokens as a planning buffer before degradation.

    3. **Anthropic context engineering guidance (internal).**
       Guidance to keep agent context dense, reference long-lived
       state through files rather than conversation history, and
       avoid letting agentic sessions run open-ended without
       checkpoints. Supports: (i) the living-snapshot design in the
       sections above, (ii) the post-compact recovery protocol in
       CLAUDE.md, (iii) the recurring-reminder pattern over a
       one-shot alert.

    Citation policy: when thresholds or reminder semantics change,
    cite the specific source. If a threshold change is not backed
    by a primary-source update, escalate it as a Rule 4 HARD_BLOCK
    rather than landing the change silently.

## INITIALIZATION

Load the router step to determine the pipeline variant and begin execution:

**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/route.md`
