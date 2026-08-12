<!-- unconditional: this rule governs what may occupy the compaction-durable channel, so it has to occupy that channel itself — a scoped copy would be discarded at the first compaction, which is precisely the event it describes. -->

# Resident-context discipline

What may sit in a file that a session re-reads, and what it costs. `core/rules/ai-dlc-resident-discipline.md`
is the CONSUMER's carrier for the shipped version of this rule; this file is the one that
binds work in this repo.

## Know which channel you are writing into

Three channels, and they behave differently under compaction:

- **`CLAUDE.md` and any `.claude/rules/` file with no `paths:` key** are re-injected on
  every compaction of every session, and they reach subagents. This is the only durable
  channel, and it is the expensive one. `scripts/validate-claude-rules.sh` holds it to a
  byte ceiling.
- **A `paths:`-scoped rule file** loads on the first matching Read or Edit, ONCE per
  session. Write, Grep, Glob and Bash do not fire it. It is NOT re-injected after a
  compaction, so after the first one it is gone for the rest of the session. A subagent's
  read loads it inside that subagent only and never reaches the parent.
- **A validator arm** runs whether anyone read anything, and is the only channel that blocks.

Scope a rule to `paths:` only when its work reliably begins with a matching read, a mechanism
carries it anyway, and no subagent needs it. Otherwise it goes in the durable channel — and
if it can be mechanized at all, it goes in a validator instead of either.

## No rationale, narrative, version tag or date in resident rule prose

`SKILL.md` costs its bytes on every turn; `steps/*.md` cost theirs on every compaction; a
role file PRIMES the agent that reads it. Origin tags and dates are blocking findings in
`core/scripts/audit-rule-files.sh` for exactly that reason. Stories belong in
`docs/context-hardening-notes.md` and provenance belongs in the CHANGELOG.

The measurement that produced a rule is the reason the rule exists and stays with it. The
story of the incident does not.

## Verbosity is deliberate scar tissue

Do not trim rule or hook text for token cost. Almost every long passage here is long because
a short one failed. Delete only VESTIGIAL prose — text whose enforcing mechanism you can NAME
and whose behavioural instruction lives authoritatively somewhere else — and grep for inbound
references before every cut.

Never justify a change in terms of tokens saved. That is not the currency.

## A rule survives a compaction only if something other than memory CARRIES it

A compaction discards most of a long rulebook, including the instructions that would tell the
session to re-read it. So for every rule, name the thing that brings it back: an unconditional
file, a hook that re-injects it, a validator that fails without it. A rule whose only carrier
is the agent's recollection is a rule with a half-life.

When a rule is written down, write down its carrier in the same change.
