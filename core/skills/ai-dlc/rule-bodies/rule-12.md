### Rule 12 -- Escalate asynchronously via file

This file is the full text of Rule 12 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

Write escalations to `docs/escalations/pending.md`. Escalations have
three tiers that determine whether work blocks or continues.

**Tier 1 -- HARD_BLOCK (work stops):**
- A finding contradicts an explicit human-approved decision.
- The agent cannot implement a requirement as specified (requirement
  divergence) and needs human sign-off on an alternative approach.
- A carry-over item deferral is proposed (`DEFERRAL_REQUEST`).

Action: mark task BLOCKED, message the lead (a teammate: `SendMessage` `to: "main"`), move to next unblocked task.

**Tier 2 -- DECIDED_AUTONOMOUSLY (work continues):**
- A trade-off has no objectively correct answer; agent picks the best
  option, documents rationale, proceeds.
- Requirements are ambiguous but can be reasonably inferred from
  context, project memory, or existing patterns.
- UI/UX direction decisions where no explicit user preference exists.
- Implementation option selection among alternatives presented in a
  carry-over item or story spec.

Action: document decision and rationale, proceed without blocking. These
bullets yield to `#### Operator decisions: sort before asking (Rule
11(a))` (in `rule-bodies/rule-11.md`): a choice that sort leaves asked is asked, whatever a bullet
above says.

**Tier 3 -- not an escalation:**
Formatting, naming, phrasing, minor refactors, test structure, or any
issue where a professional default exists. Just do it.

The escalation entry format (append, do not overwrite) and the
resolution lifecycle (how HARD_BLOCK / DEFERRAL_REQUEST / DECIDED
statuses are closed at the production checkpoint) live in
`escalations.md` alongside this file. READ AND FOLLOW it (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) when writing or
resolving an escalation.

When resolving a HARD_BLOCK changes how an acceptance criterion is
verified (moving it between verification categories), the resolution MUST
disclose the change for explicit operator acknowledgement — mechanism in
`escalations.md` "AC verification-category-change disclosure".
When a later event shows an outcome an earlier authorization relied on did
not occur, the question returns to the operator — `escalations.md`
"Authorization-premise invalidation disclosure".
