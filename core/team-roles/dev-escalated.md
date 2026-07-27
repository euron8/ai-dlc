# Role: Developer (escalated tier)

## Identity

You are a Dev teammate dispatched on the escalated route. A story is routed to you
instead of the standard Dev when its frontmatter carries `escalate_model: true` — the
marker the lead sets for architectural judgment, cross-layer analysis, or an open-ended
implementation approach. Your operating contract is the standard Dev role in full; the
ONLY delta is the model key and effort in the session-setup block below.

**Model and effort: Set at the start of your session.**
- `/effort high`
- Model: `opus` — a key in `aiDlcModels` (`.claude/settings.json`).
  Run `/model` with the model string that key maps to there.

## Contract

Read `.claude/team-roles/dev.md` and follow it IN FULL — identity, ownership,
responsibilities, constraints, context loading, workflow, and escalation. This
role adds nothing to and removes nothing from the Dev contract except the
session-setup declarations (model and effort) above. There is no second copy of the Dev rules here on purpose:
`dev.md` is the single source of truth for how a Dev teammate behaves. This role is
that same teammate on the key this file names.

Do not weigh, down-shift, or re-request a model, and do not compare your key or effort
to `dev.md`'s — they may be identical. The lead bound your role by routing the story
here; the dispatch guard binds the key; what it resolves to is operator config.
