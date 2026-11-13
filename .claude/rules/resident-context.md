<!-- unconditional: this rule governs what may occupy the compaction-durable channel, so it must occupy that channel itself. -->

# Resident-context discipline

What may sit in a file that a session re-reads. `core/rules/ai-dlc-resident-discipline.md` is the CONSUMER's
carrier for the shipped version; this file binds work in this repo.

## Know which channel you are writing into

- **`CLAUDE.md` and any `.claude/rules/` file with no `paths:` key** are re-injected on every compaction of
  every session and reach subagents. This is the only durable channel and the expensive one;
  `scripts/validate-claude-rules.sh` (arm A6) holds it to a byte ceiling.
- **A `paths:`-scoped rule file** loads on the first matching Read or Edit, ONCE per session; Write, Grep, Glob
  and Bash do not fire it. It is not re-injected after a compaction, and a subagent's read loads it inside that
  subagent only.
- **A validator arm** runs whether anyone read anything and is the only channel that blocks.

Scope a rule to `paths:` only when its work reliably begins with a matching read, a mechanism carries it
anyway, and no subagent needs it. Otherwise it goes in the durable channel — and if it can be mechanized, in a
validator instead.

## Always-loaded rule prose carries rules and directions only

Incident stories, measurements, figures, dates, batch or version numbers used as provenance, operator
quotations used as justification, and "why" paragraphs live in the operator's memory directory
(`~/.claude/projects/-Users-n8-git-ai-dlc/memory/`), `docs/context-hardening-notes.md` or the CHANGELOG, never
in this channel. State the rule, the concrete detail needed to follow it (paths, commands, flags, env vars,
invariant ids, arm names) and the hazard's shape. `core/scripts/audit-rule-files.sh` blocks origin tags and
dates. Delete a passage only if it is vestigial: its enforcing mechanism can be NAMED and its behavioural
instruction lives authoritatively elsewhere; grep for inbound references before every cut. The same applies to
`SKILL.md`, `steps/*.md` and role files: no rationale, narrative, version tag or date;
`core/scripts/audit-rule-files.sh` blocks origin tags and dates there.

## A rule survives a compaction only if something other than memory CARRIES it

For every rule, name the thing that brings it back: an unconditional file, a hook that re-injects it, or a
validator that fails without it. When a rule is written down, write down its carrier in the same change.
