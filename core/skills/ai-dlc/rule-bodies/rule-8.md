### Rule 8 -- Run the validation cycle per declared intensity

This file is the full text of Rule 8 of `SKILL.md`; the stub in that file is the load pointer. The intensity table below is a copy of the stub's table, which owns it (bound by I131); change the table only in the stub. It ships with the skill and is audited as rule prose under the same standard as the stub.

Validation intensity is declared at route time (see route-fresh-start.md Step 6)
and recorded in the pipeline snapshot as `validation_intensity`. The
intensity determines the MINIMUM validation cycle at each planning
phase. The lead MUST NOT run less than the declared minimum.
`test-strategy.md` is the one exception: its minimum is the convergence
review alone (`steps/stories-test-strategy.md` §5 step 2). Running
more is always permitted.

| Intensity | Trigger | Minimum cycle per planning artifact |
|---|---|---|
| `full` | ≥3 stories touching service code paths | Party Mode → Advanced Elicitation → Adversarial Review |
| `standard` | 1-2 stories touching service code paths | Party Mode → Adversarial Review |
| `carry-over-single` | carry-over variant with ≤2 stories touching service code paths | Party Mode → Adversarial Review |
| `lightweight` | All stories touch only pipeline-infra paths | Adversarial Review at discovery (or requirements) + stories-test-strategy only |

**The Adversarial Review runs until a pass stamps `EXIT_CONDITION_MET`. That
verdict is the only thing that ends it, and it is honoured the moment it is met,
including at pass 1.** The residue that decides it: `team-roles/adversary.md`.
Pass 2+ reviews the REPAIR, not the document again, and verifies the prior
pass's findings landed.

**A MAJOR whose every quoted span the previous repair wrote does not block the exit, and is
still repaired, never deferred:** `team-roles/adversary.md`, "The verdict".

**Divergence is a HARD_BLOCK, not a reason for another pass.** Pass N+1's
`findings_critical_prior_scope` above pass N's `findings_critical` means the repair
is injecting defects. STOP and escalate. A blocking MAJOR count above
`MAJOR_EXIT_CEILING`, at no more than `CRITICAL_EXIT_CEILING` CRITICAL, not reduced
across more than `STALL_THRESHOLD` consecutive passes is a STALL, and stops the cycle
the same way. CRITICALs in scope ADDED
mid-cycle are NOT divergence: no cycle converges on a growing artifact -- freeze
scope, shrink the sprint, restart. Contract: `team-roles/adversary.md`.

**A series is bounded at p3.** A p3 that does not stamp `EXIT_CONDITION_MET` stops the
cycle as a STALL does, and the next pass must declare `resolves_divergence:`. A pass after
the first is dispatched over the parts `merge-adversarial-shards.sh --derived-map` prints; in files mode that
is narrowed to the repair; in document and subject modes it is narrowed by the pass file's `part_sha:` and `part_run:` fields, and falls to the full map with a `full width:` reason where a list is missing or unjoinable. Procedure:
`steps/_gate-procedures.md`, "Divergence resolution dispatch".

**A stop is not the end of the cycle: STOP -> ADJUDICATE -> RESOLVE -> VERIFY.** A repair
edits the artifact on UNCHANGED scope -- that is what diverged. A RESOLUTION changes what
is under review, is written to a record the gate reads, and is followed by ONE verification
pass in the SAME series. Until that record exists the hooks deny every dispatch. FREEZE is
NOT a resolution. Kinds + procedure: `steps/_gate-procedures.md`.

The per-intensity skips are enforced by each planning step's own
intensity gate, not tracked centrally. Follow each step's gate.

`carry-over-single` may only be assigned to carry-over variants. If
actual story count exceeds 2 at `stories-test-strategy`, intensity MUST
be revised upward to `standard`.

The gate log MUST record the declared intensity and confirm the
minimum was met. A gate that passes under `lightweight` with zero
adversarial passes at discovery (or requirements) is a violation.

Intensity does NOT reduce the following (always required regardless):
- Carry-over eval party mode (evaluates slot/close/defer decisions)
- Story validation party mode (real subagents)
- Adversarial review on stories and sprint output (run it; converge it)
- Deploy-validate smoke test (hard gate, see deploy-validate.md)
- Retro party mode (Rule 20 Skill invocation mandate)
