### Rule 26 -- Minimum mechanism (KISS)

This file is the full text of Rule 26 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

Every produced artifact -- design, code, test, guard, or process
machinery -- MUST use the smallest mechanism that satisfies the
locked requirements and acceptance criteria.

**(a) No speculative mechanism.** MUST NOT add abstractions,
configuration options, fallbacks, guards, or generality for
requirements that do not exist. Unrequested capability is scope
creep, not thoroughness. An abstraction, interface, or
parameterization introduced with exactly one call site violates this
clause unless a second concrete consumer lands in the same story or a
(b) rationale record names it.

**(b) Extend proven paths.** When a working path covers the
requirement, extend it. Each of the following requires documented
rationale -- an ADR at design time, a DECIDED_AUTONOMOUSLY entry
(Rule 12) at implementation time:

- a parallel path beside a proven one: why extension is insufficient;
- a new third-party dependency: what it replaces, and why the standard
  library or an already-present dependency will not do;
- caching, pooling, or any optimization: the measurement that showed
  the need.

**(c) Guard machinery carries a contract.** New guard, gate, hook,
or process machinery MUST state at introduction: the concrete failure
it catches, the cost of a false positive, and the condition under
which it is removed. Machinery that cannot state all three is not
added.

**(d) Simplification is first-class.** Review and validation passes
MUST treat removal and simplification findings as equal in standing
to additions. A finding that adds mechanism MUST state why a simpler
change is insufficient.

**(e) Scope fence.** This rule governs the shape of what is produced.
It never authorizes skipping, thinning, or reordering pipeline steps,
gates, or validation cycles -- Rule 4 is unaffected, and "simple" or
"KISS" is never a reason to bypass a step.

Violation is a MAJOR in adversarial review (`adversary.md`) and a
code-review finding (`code-reviewer.md`); machinery lacking the (c)
contract is flagged by the retro rule-file audit (`retro.md` Step 4).
