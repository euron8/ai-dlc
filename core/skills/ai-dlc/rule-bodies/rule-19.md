### Rule 19 -- Agent spawns MUST bind the full role contract

This file is the full text of Rule 19 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

When the lead invokes the Agent tool to spawn a teammate, the spawn MUST
bind that teammate to its role file (`.claude/team-roles/<role>.md`) --
the whole contract, not just the model. Two bindings are mandatory:

**(a) Model.** `render-agent-definitions` renders
`.claude/agents/<role>.md` from `aiDlcRoles.<role>` — that generated
definition is the binding: a role-bound dispatch naming it as
`subagent_type` runs on its `model:` and its `effort:` both, which is
also what makes (c) below load-bearing. The `ai-dlc-dispatch-guard`
PreToolUse hook selects between two branches on every role-bound
dispatch. When a matching, non-stale definition exists, the guard
rewrites `subagent_type` to it and DELETES both `name` and `model` from
the call — the rendered definition is the one source, and an explicit
`model` param would outrank it. When no matching definition exists, or
the definition's frontmatter disagrees with `aiDlcRoles.<role>` (a
stale render), the guard falls back to today's behaviour as the net
under the definition, not the norm: it resolves `aiDlcRoles.<role>.model`
and injects the `model` parameter itself. Do NOT restate a
role-to-model mapping here or in step files; a second mapping drifts
from the role file and is itself a violation. A spawn that omits
`model` on the fallback path, names a different key, or lacks a
matching definition where one is expected, is still a Rule 19 violation
Check 22 records at retro.

**Config is authoritative.** `aiDlcRoles.<role>` states the model and the
effort; the rendered definition (a) is what binds both. The guard also
appends a sentence stating the configured effort to the prompt -- the
Agent tool has no effort parameter for the guard to set directly, so on a
role dispatched without a definition that sentence is the fallback signal,
not a harness-enforced value. Evaluate neither value. An `-escalated` role MAY
name the same model and the same effort as its base role; that is valid
config. Do not flag, question, or negotiate either -- not in a dispatch
prompt, a gate log, a handoff, or a retro. Config is the operator's to
change.

**(b) Role contract.** The dispatch prompt MUST carry, as a standing
line, the instruction: *"Your operating contract is
`.claude/team-roles/<role>.md`. Read it and follow it as your FIRST
action before any other work."* This puts the role's identity,
ownership, constraints, and escalation protocol into the *subagent's*
context (not the lead's, per Rule 23), and mirrors Rule 21 -- the read
IS the binding, not the lead's recall. Keep the line byte-identical
across dispatches so it rides the shared-block cache
(`implementation.md` dispatch-prompt cache discipline); vary only the
`<role>` token. A spawn that names a role but omits this line binds
model without contract and is a Rule 19 violation.

The line is DELIVERED by either of two carriers: the dispatch prompt, or
the rendered `.claude/agents/<role>.md` definition the dispatch selects,
whose body is the subagent's system prompt and carries the line for that
role. The dispatch guard records which carrier delivered it
(`role_contract_cited`, `contract_via`), at PreToolUse. That record is
of delivery as selected: it does not prove the spawn launched, and it
does not prove the teammate read the file. Delivery puts the line in
front of the teammate; the read is still the binding.

**(c) No `name` on a role-bound dispatch.** The spawn MUST NOT pass a
`name` parameter. Passing one routes the spawn to the teammate runner
instead of the resume-by-id path a definition-bound dispatch runs on,
and that runner applies the definition's `model` but not its `effort` --
so a named role-bound dispatch silently drops the effort half of (a).
Reach a role-bound hand afterward by `SendMessage` to the agent id
`ListAgents` reports; that is resume-by-id, not the named-teammate inbox
the "`SendMessage` reaches a resident teammate" passage below describes,
and a lead expecting that inbox is looking in the wrong place. Dropping
`name` costs nothing else: its one mechanical reader in the tree is the
dispatch guard's ledger row, which already falls back to `subagent_type`
when `name` is absent, and Rule 20 joins every teammate on its
deliverable file, never on `name`.

Violation of (a), (b), or (c) fails gate-validation Check 22 on detection
at retro.
