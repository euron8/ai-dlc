### Rule 30 -- The spec is BMAD's; the enforcement is ours

This file is the full text of Rule 30 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

Specification artifacts MUST be produced by the BMAD workflows that own them and
MUST NOT be reimplemented in this rulebook: the spec kernel by `bmad-spec`, the
design spine by `bmad-architecture`, and epics and the FR coverage map by
`bmad-create-epics-and-stories`. BMAD is a prerequisite; a second implementation of a
workflow it ships is a parallel path beside a proven one and violates Rule 26(b).

**A BMAD finding is not a BMAD verdict.** `lint_spine.py` exits 0
unconditionally and leaves the call to its caller; `bmad-check-implementation-
readiness` reports uncovered requirements without failing anything;
`bmad-testarch-trace` emits a gate decision that blocks nothing;
`bmad-spec`'s Spec Law is graded by the agent that authored the spec. Every one
of those MUST be adopted by a gate check that can FAIL, and the gate check MUST
re-derive its own judgement rather than adopt a self-declared verdict. A
finding nothing acts on is a finding that reads exactly like a clean run.

**A re-rendered artifact is never an anchor.** `bmad-spec` is the sole writer of
`SPEC.md` and re-derives it from `.memlog.md` on every run, so a byte anchor
there holds until the next derive and then either passes against reworded text or
reports a drift that never happened. Byte anchors (Rule 13, Check 3b) keep
targeting the product brief; a derived artifact — `prd.md`, `SPEC.md`, a spine —
is cited with `requires_context:`, never `full_text_source:`. Anything read for
its ID SET rather than its text may be read anywhere.

**Spec derivation is delegated (Rule 28) and escalated (Rule 19).** It is not
orchestration, routing, or a gate decision, so the lead MUST NOT run it inline;
it routes to `pm-escalated`, whose model comes from its `aiDlcRoles` entry and
not a call-site argument.

Violation is a MAJOR adversary finding and a `code-reviewer` finding. Retire
this rule if BMAD stops shipping the workflows it names, or starts failing on
its own findings.
