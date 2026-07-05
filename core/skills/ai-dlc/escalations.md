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
**Decision/Question:** [For DECIDED_AUTONOMOUSLY: what was decided and why. For HARD_BLOCK: the specific decision needed from the human]
**Options:** [If applicable, the options considered and their trade-offs]
**Impact if skipped:** [What happens if work continues without this answer]
```

**Resolution lifecycle:** HARD_BLOCK / DEFERRAL_REQUEST resolved by human
at the production validation checkpoint; status updated to RESOLVED with a
decision. DECIDED_AUTONOMOUSLY reviewed by human at the checkpoint; no
action unless the decision was wrong, in which case status updates to
OVERRIDDEN with corrective direction.
