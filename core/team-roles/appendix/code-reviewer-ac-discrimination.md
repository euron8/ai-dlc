# Code Reviewer appendix: UNIVERSAL, LOCKED_REQUIREMENT and bound ACs

### UNIVERSAL AC Missing Discriminating-Failure Fixture = Important

Any AC tagged UNIVERSAL that lacks a discriminating-failure fixture
(a test that FAILS when the universal property is violated for a
single instance) MUST be classified as **Important**. The fixture
proves the test is load-bearing, not tautological.

### LOCKED_REQUIREMENT With No Discriminating AC = Critical

A `LOCKED_REQUIREMENT` whose mapped acceptance criteria are ALL
satisfied by a null or degenerate-but-type-valid implementation (an
implementation that violates the requirement while passing every
safety invariant) MUST be classified as **Critical**, non-deferrable.
The reviewer MUST name the degenerate implementation and confirm ≥1
mapped AC reds against it; if none does, the requirement is
unimplemented-but-green. Reviewer's only valid responses: (a) APPROVED
if a mapped AC reds under the named degenerate impl; (b) NEEDS_REWORK
naming the missing discriminating AC.

### Bound/Limit AC Asserting Wrong Direction = Critical

For any AC guarding a bound, limit, or ceiling, the reviewer MUST
verify the AC asserts the bound in the protective direction (the side
that constrains the risk for the operation's direction), not merely
the absence of the known failure mode. An AC that stays green under a
wrong-side bound MUST be classified **Critical**, non-deferrable.
