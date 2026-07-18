# Research Citations -- Context Threshold Design

This file documents the research backing the token thresholds,
reminder semantics, and recovery protocol in `SKILL.md` Handoff
Protocol and Pipeline Snapshot section. It is referenced from
SKILL.md but not loaded automatically; agents MUST read this file
only when verifying threshold choices or considering changes to
reminder semantics.

The lead MUST NOT change thresholds or reminder semantics without
citing the specific source here. If a threshold change is not backed
by a primary-source update, escalate as Rule 12 HARD_BLOCK rather
than landing the change silently.

## Sources

### 1. Chroma Hong et al. 2025, "Context Rot" technical report

Empirical evidence that LLM reasoning accuracy declines with absolute
input length on multi-hop and needle-in-haystack tasks, with
degradation measurable well before the nominal context window limit.

Supports:
- Use of absolute token thresholds rather than fraction-of-window.
- General shape of a yellow/red two-stage alerting model with the
  first inflection in the tens-of-thousands-of-tokens range.

### 2. Claude Code empirical observation

On reasoning-heavy agentic workloads in a 200K context window,
practitioners report observable degradation beginning around ~147K
input tokens (roughly 70-75% of nominal).

Supports:
- The red threshold at 120K tokens for 200K models (first-order
  warning zone rather than catastrophe zone).
- The yellow threshold at 80K tokens as a planning buffer before
  degradation.

### 3. Anthropic context engineering guidance (internal)

Guidance to keep agent context dense, reference long-lived state
through files rather than conversation history, and avoid letting
agentic sessions run open-ended without checkpoints.

Supports:
- The living-snapshot design in SKILL.md Handoff Protocol.
- The Post-Compact Recovery Protocol in SKILL.md.
- The recurring-reminder pattern over a one-shot alert.

### 4. Claude Code skill content lifecycle (Anthropic docs)

Skills that are invoked during a session are re-attached after
auto-compact, keeping the first 5,000 tokens of each invoked skill,
sharing a combined 25,000-token budget across all re-attached skills.
Older skills can be dropped after compaction if many have been
invoked. The documented fallback is to re-invoke the skill to restore
its full content.

Source: https://code.claude.com/docs/en/skills -- "Skill content
lifecycle" section.

Supports:
- The "first 5K" structural constraint that governs SKILL.md
  organization (Rules 1-13 plus Handoff Protocol plus Post-Compact
  Recovery Protocol must fit within 5,000 tokens).
- The re-invocation fallback documented in Post-Compact Recovery
  Protocol.

## Citation Policy

When any of the following change, cite the specific source in the
commit message:

- Yellow or red token threshold values.
- Reminder recurrence arithmetic (currently 50K tokens / 20 turns).
- Context sensor measurement semantics (the `usage` summation, the
  ~31,000-token sensor-visible reserve, the model-row inference).
- The first-5K SKILL.md structural constraint.
- The auto-handoff precondition-gated firing model.

A change to any of these without a primary-source update MUST be
escalated as Rule 12 HARD_BLOCK. These are not matters of style or
preference; they are the architectural invariants the reliability
research supports.
