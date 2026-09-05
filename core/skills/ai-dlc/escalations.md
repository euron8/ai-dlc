# Escalation Entry Format and Resolution Lifecycle

Referenced by SKILL.md Rule 12 and the team role files (`dev.md`,
`qa.md`, `architect.md`, `code-reviewer.md`). READ AND FOLLOW when
writing or resolving an escalation in `docs/escalations/pending.md`. The
three-tier decision (HARD_BLOCK / DECIDED_AUTONOMOUSLY / not-an-escalation)
that governs *whether* to escalate stays in SKILL.md Rule 12; this file
holds *how* to write and resolve one.

**Who the operator is.** The **operator** is the human driving the session.
It is NOT the lead and NOT any subagent. A message counts as an operator message
only when it originates from a human turn in the session transcript — the same
predicate `scripts/ai-dlc/validate-steering-budget.sh --cite` applies. Every role
file's "never prompt the human directly" rule and every `operator_authorization`
citation refer to this one party. A lead that writes a resolution on its own
authority has made a `DECIDED_AUTONOMOUSLY` call, whatever it labels it.

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

**Terminal statuses** (set at resolution, never at authorship): `RESOLVED | OVERRIDDEN | SUPPRESSED`

Those two lines — the `**Status:**` line in the format block above and the terminal
list here — are the CLOSED vocabulary. Every token an entry's `**Status:**` field may
carry appears in exactly one of them, and `scripts/ai-dlc/validate-escalation-status-vocabulary.sh`
derives its set by reading them rather than restating it. A status outside the set is
malformed: `gate-validation.md` Check 2 branches on these tokens and has no else, so an
entry carrying a sixth token is not blocked, not surfaced and not recorded — Check 2
computes no verdict for it and reports PASS. Adding a token means editing one of these two
lines, which is the point.

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

At the gate, `scripts/ai-dlc/validate-escalation-resolution.sh` verifies that
substring against the session transcript (this sprint's entries only;
legacy sprints are out of scope), using the same genuine-operator
predicate Rule 29 uses. A `RESOLVED` you authored yourself, with no
operator message behind it, is not a resolution — it is a fabricated
disposition, and the gate FAILS on it. If you genuinely made the call,
its status is `DECIDED_AUTONOMOUSLY` (informational, non-blocking, no
citation required) — the honest label.

The citation is written in the SAME edit that sets the status. An edit
flipping an entry to `RESOLVED` / `OVERRIDDEN` without the
`**Operator authorization:**` line is incomplete, not pending — never a
follow-up. The decay path is a handoff to a fresh session: a successor
lead cannot reconstruct a verbatim substring it never received, so a
citation deferred past the edit is not late, it is unrecoverable except
by asking the operator to repeat themselves.

**SUPPRESSED — an authorization to proceed past a failing check, with a
lifetime.** `RESOLVED` and `OVERRIDDEN` close a *question*. Neither closes a
*check*, and using one for that is how a red check stops being re-argued while
it is still red. Measured on the reference consumer: a `hard_block: true` check
failed at two consecutive planning gates and the pipeline proceeded past both
on a single operator turn, each passage logged as *"carried forward, none
re-litigated"*.

**What that measurement did NOT show, and it decides the mechanism:** the
check was not silenced. It ran at every gate and reported `FAIL` at every gate,
and the metrics record it. What was reused was the AUTHORIZATION. So the
lifetime here bounds how long an operator's *permission to proceed* stays in
force — not whether the check re-runs, which it already does. A suppression
that expires does not un-silence anything; it withdraws the licence to walk
past a verdict that is still red.

A `SUPPRESSED` entry MUST carry, in the same edit that sets the status:

```
**Suppresses:** [<catalog>] <check-id> — <check title>
**Expires after:** <n> gates
**Operator authorization:** <ISO-8601 UTC ts> | "<verbatim substring, ≥12 chars, of the operator's message>"
```

`<n>` defaults to 1 and may not exceed 3. **`<n>` counts gates RECORDED after the
authorization, and the gate whose checks are running is recorded after they
run — so an entry covers the authorizing gate and then `<n>` more.** `<catalog>` is `core` for a
distribution check and `extension:<id>` for a consumer domain check, matching
the `GATE_METRIC v1` field of the same name — the id is a join key, so it is
written the way the metrics write it. The `**Operator authorization:**` line
carries the identical grammar and the identical verification as the
`RESOLVED`/`OVERRIDDEN` citation above; a suppression is an operator decision
or it is nothing.

**A suppression names its target.** `RESOLVED` and `OVERRIDDEN` name none, and
that is the loophole: an entry may be closed on an operator's word while a
check id sits in its body, still failing, with nothing joining the two. So a
terminal entry that names a currently-failing check id and is NOT `SUPPRESSED`
is malformed — use `SUPPRESSED` and declare the target and the lifetime, or
resolve the underlying failure.

**Past expiry the entry authorizes nothing.** Once `<n>` gates have been
recorded since the authorization timestamp, a still-failing named check is a
live failure again and the gate must obtain fresh authorization. The prior
citation may not be re-cited; re-suppression is a new entry with a new operator
turn. Enforced by `scripts/ai-dlc/validate-suppression-lifetime.sh` at Check 2,
which counts elapsed gates from `gate-metrics.jsonl` and re-reads the named
check's own recorded verdict — so a suppression whose cause has genuinely been
fixed costs nothing, and only one that is still red is stopped.

**An escalated check is covered the same way.** The `adjudication: llm` checks
are adopted only through Check 26, whose validator asks the same script
(`--in-force`) before it blocks on a per-check `FAIL`; a FAIL the adjudicator
recorded stays recorded, and an in-force entry naming `[<catalog>] <check-id>`
in the verdict's own catalog is what lets the gate proceed past it. An entry
that names the wrong catalog, is malformed, or is past its lifetime covers
nothing there, exactly as at Check 2.

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

**Permanent-default change disclosure.** When resolving a HARD_BLOCK
changes a PERMANENT DEFAULT — a standing policy the pipeline keeps
applying after the entry closes (model routing, a config default, a
gate's severity, a role's `/model` pin) — the resolution MUST state the
change and its ongoing cost for operator acknowledgement:
`Permanent default <name> changed <old> → <new>. Ongoing cost: <what it
now affects on every future run>. Operator ack Y/N`. A point fix pays its
cost once; a permanent-default change keeps charging on every future run,
so folding it silently into a HARD_BLOCK resolution hides a standing
policy change inside a one-time fix. The operator's `Y` is required
before the resolution closes; a `N` reverts the default. Same enforcement
path as the sibling above — the `RESOLVED`/`OVERRIDDEN` operator citation
(`validate-escalation-resolution.sh`) is what makes a fabricated ack fail.
Governed by SKILL.md Rule 12.

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
