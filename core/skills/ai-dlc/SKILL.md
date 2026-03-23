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
2. **Single conversation.** Do not ask the user to start new sessions. Run
   the entire pipeline in this conversation.
3. **Autonomous gates.** At each phase transition, run the Autonomous Gate
   Protocol (CLAUDE.md). Do not wait for human approval.
4. **Seek clarity when ambiguous.** If the user's request is genuinely
   ambiguous, ask a targeted clarifying question before proceeding. Do not
   guess at intent when asking would be faster and more accurate.
5. **Requirements are locked.** You have autonomy over HOW to implement.
   You do NOT have autonomy over WHAT is implemented. Any requirement
   divergence is a HARD_BLOCK (CLAUDE.md Rule 8).
6. **Production validation is the only human checkpoint.** After deployment
   and smoke tests, present the Production Validation Checkpoint to the
   human (CLAUDE.md Post-Gate Deployment).
7. **Never stall the pipeline.** The pipeline runs as a continuous,
   uninterrupted flow. There are exactly THREE points where you stop
   and wait for human input:
   - (a) Ambiguity resolution (Rule 4)
   - (b) Production Validation Checkpoint (Rule 6)
   - (c) Retro commentary prompt

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

## INITIALIZATION

Load the router step to determine the pipeline variant and begin execution:

**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/route.md`
