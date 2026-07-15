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

**RESOLVED / OVERRIDDEN must CITE the operator.** A HARD_BLOCK exists
because the decision is the operator's; marking it `RESOLVED` (or a
DECIDED_AUTONOMOUSLY entry `OVERRIDDEN`) asserts the operator adjudicated
it. So the entry MUST carry a citation of the operator's own message —
not a paraphrase, not the lead's summary:

`**Operator authorization:** <ISO-8601 UTC ts> | "<verbatim substring, ≥12 chars, of the operator's message>"`

At the gate, `scripts/validate-escalation-resolution.sh` verifies that
substring against the session transcript (this sprint's entries only;
legacy sprints are out of scope), using the same genuine-operator
predicate Rule 29 uses. A `RESOLVED` you authored yourself, with no
operator message behind it, is not a resolution — it is a fabricated
disposition, and the gate FAILS on it. If you genuinely made the call,
its status is `DECIDED_AUTONOMOUSLY` (informational, non-blocking, no
citation required) — the honest label. This is the S290 fix: six
`S290-* Lead (…)` entries were flipped to RESOLVED in a window with zero
operator messages, and nothing compared the claim to the transcript.

**AC verification-category-change disclosure.** When resolving a
HARD_BLOCK changes how an acceptance criterion is verified — moving it
between verification categories (e.g. discriminator → smoke-only,
directly-tested → deferred/deploy-pending, hard-gate → advisory) — the
resolution MUST state the change explicitly for operator acknowledgement:
`AC <N> verification category <old> → <new>. Operator ack Y/N`. A
category change lowers or relocates the evidence bar the operator
originally signed off on; slipping it through inside a HARD_BLOCK fix
without an explicit ack silently downgrades the acceptance contract. The
operator's `Y` is required before the resolution closes; a `N` returns
the AC to its prior category. Governed by SKILL.md Rule 12.

**Terminal-entry archival (Rule 25(a)/(c) — move, never delete).** Once
an entry reaches a terminal status — RESOLVED or OVERRIDDEN — it is
MOVED (cut-and-paste, verbatim) out of the live `pending.md` into a dated
escalation archive (`docs/escalations/pending-archive.md`) at retro
close. The live `pending.md` holds only OPEN escalations (HARD_BLOCK
awaiting sign-off, DEFERRAL_REQUEST awaiting disposition). Nothing is
dropped — the union of live + archive preserves every entry — but the
gate-read that scans `pending.md` for open blockers stays bounded to what
is actually open, not the full resolved history. This is the escalation
log's instance of the Rule 25 no-loss archival family.

**Minimum mechanism (Rule 26(c)).** Failure caught: an unbounded
`pending.md` where each gate re-reads the entire resolved history to find
the few open blockers, and where a stale RESOLVED entry can be misread as
still-open. False-positive cost: one cut-and-paste per terminal entry at
retro close. Removal condition: retire once escalation status is tracked
in a store that filters open-vs-terminal at query time rather than by
file partition.
