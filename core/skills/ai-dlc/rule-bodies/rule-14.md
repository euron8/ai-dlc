### Rule 14 -- Multi-sprint phasing is autonomous

This file is the full text of Rule 14 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

When the agent determines a feature exceeds single-sprint scope due
to size or risk, the agent may autonomously split it into phased
sprints without human approval. Requirements: document the phasing
rationale, define phase boundaries, ensure each phase delivers
standalone value. Each sprint is deployed and validated at the
production checkpoint before the next sprint begins.

**Minimum mechanism (Rule 26(c)).** Failure caught: a feature too large
or too risky for one sprint shipped whole, or a phase started on top of
an unvalidated one. False-positive cost: one extra production checkpoint
when a feature is phased that one sprint could have carried. Removal
condition: a gate that refuses an oversized sprint mechanically.
