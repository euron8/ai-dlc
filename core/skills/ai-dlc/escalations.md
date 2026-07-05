# Escalation Entry Format and Resolution Lifecycle

Referenced by SKILL.md Rule 12 and the team role files (`dev.md`,
`qa.md`, `architect.md`, `code-reviewer.md`). READ AND FOLLOW when
writing or resolving an escalation in `docs/escalations/pending.md`. The
three-tier decision (HARD_BLOCK / DECIDED_AUTONOMOUSLY / not-an-escalation)
that governs *whether* to escalate stays in SKILL.md Rule 12; this file
holds *how* to write and resolve one.

**Escalation entry format (append, do not overwrite):**

```
## [STORY-ID] [Teammate Name] - [Date/Time]
**Status:** HARD_BLOCK | DECIDED_AUTONOMOUSLY | DEFERRAL_REQUEST
**Blocker type:** [contradicts decision | requirement divergence | trade-off | missing requirement | scope change | deferral]
**Context:** [What you were doing when you hit the issue]
**Evidence observed:** [HARD_BLOCK REQUIRED: only concrete, directly-verifiable facts actually observed — log lines anchored to file:line, command output, measured values, tool results, file contents. Nothing inferred.]
**Assertion (beyond evidence):** [HARD_BLOCK REQUIRED: every claim, inference, or root-cause hypothesis that goes beyond the evidence above. If there is none, write "none — assertion equals evidence." A handoff successor MUST treat this field as unverified until independently re-confirmed.]
**Decision/Question:** [For DECIDED_AUTONOMOUSLY: what was decided and why. For HARD_BLOCK: the specific decision needed from the human]
**Options:** [If applicable, the options considered and their trade-offs]
**Impact if skipped:** [What happens if work continues without this answer]
```

The `Evidence observed:` / `Assertion (beyond evidence):` pair is
MANDATORY on every HARD_BLOCK. A HARD_BLOCK that conflates an observed
fact with an inferred root cause propagates the inference as settled
truth across a handoff or a checkpoint review — the successor or
operator then acts on an unverified assertion as if it were evidence.
Separating the two forces the filer to mark the verified floor
explicitly and quarantine every claim above it. A HARD_BLOCK missing
this pair is malformed and MUST be corrected before it is presented at
the production validation checkpoint. Rule 12 owns the tiers: only
HARD_BLOCK requires both fields populated; DECIDED_AUTONOMOUSLY and
DEFERRAL_REQUEST may leave `Assertion` as "none".

**Minimum mechanism (Rule 26(c)).** Failure caught: a HARD_BLOCK whose
root-cause hypothesis is stated as established fact, so a post-handoff
successor or the checkpoint operator acts on an unverified inference as
proven. False-positive cost: one line ("none — assertion equals
evidence") when a blocker genuinely has no inference beyond its
evidence. Removal condition: retire if handoffs and the production
validation checkpoint are both eliminated, or a separate verification
step independently re-confirms every root-cause claim before it can be
acted on.

**Resolution lifecycle:** HARD_BLOCK / DEFERRAL_REQUEST resolved by human
at the production validation checkpoint; status updated to RESOLVED with a
decision. DECIDED_AUTONOMOUSLY reviewed by human at the checkpoint; no
action unless the decision was wrong, in which case status updates to
OVERRIDDEN with corrective direction.
