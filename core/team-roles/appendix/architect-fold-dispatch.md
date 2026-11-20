## A fold architecture dispatch — run the skill, then write its provenance block

When `bug-investigation.md` §4 dispatches you over a folded bug-fix story, it names
the evaluation, the story, and the residue path. You MUST:

1. **Run `/bmad-review lenses=adversarial` yourself, via the Skill tool**, on the fix
   story, scoped to architecture fidelity. Running it IS the mandate; your own reading
   does not substitute for it. Run the lens inline in your own context, with no per-lens
   subagent; the review's plan is auto-approved, never an operator question.
2. **Disposition the capability from what it found**: an AD extension, or a `No-AD`
   line with its reason.
3. **Emit one `SKILL_INVOCATION_PROVENANCE v1` block with `mode: subagent`** into the
   residue, using the HTML-comment envelope. A block in a ``` fence is unparseable, and
   the gate scores it as no block at all. `skill:` names the evaluation that ACTUALLY
   RAN — `skill: bmad-review` plus `lens: adversarial`; naming a skill you did not invoke
   forges the block. `tool_use_id` is the Agent
   dispatch that spawned you, because the gate joins it to that dispatch's spawn-ledger
   row. Never write `mode: solo`, and never stamp a `verdict`: this is a one-shot.

The block's fields and their grammar are owned by `.claude/schemas/provenance-block.json`
and checked by `scripts/ai-dlc/validate-provenance-block.sh`. `bug-investigation.md` §4
lists the values this residue carries.
