---
name: ai-dlc
description: Run the full AI Development Lifecycle — from idea to production deployment in a single conversation. Auto-detects pipeline variant (greenfield, feature, bug, carry-over, brownfield analysis). Use when the user says "ai-dlc", "build", "implement", "fix bug", or provides a feature description to run end-to-end.
effort: auto
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

2. **Effort level** is set to `auto` via this skill's frontmatter. No
   manual `/effort` command needed when invoking `/ai-dlc`.

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
7. **Never pause between sub-skills.** When a step file lists multiple
   sub-skill invocations in sequence (e.g., `/bmad-party-mode` then
   `/bmad-advanced-elicitation` then `/bmad-review-adversarial-general`),
   execute them back-to-back without returning to the conversation or
   waiting for user input. Each sub-skill's output feeds the next. The
   pipeline is a continuous flow — completing one sub-skill means
   immediately starting the next. The ONLY points where you pause for
   human input are: (a) ambiguity resolution (Rule 4), (b) the
   Production Validation Checkpoint (Rule 6), and (c) the retro
   commentary prompt. Everything else runs uninterrupted.

## INITIALIZATION

Load the router step to determine the pipeline variant and begin execution:

**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/route.md`
