### Rule 31 -- A countable assertion carries the derivation that produced it

This file is the full text of Rule 31 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

Any sentence asserting a count over a corpus -- "N sites", "all N", "N of M",
"every one of the N" -- MUST carry, in the same block, the command or the
citation set that produced the number. A count authored without one is a fact
the reader cannot check and the author did not run, and it is indistinguishable
from a guess.

**This binds prose, not only acceptance criteria.** A count in a disposition,
scope note, out-of-scope declaration, investigation baseline, or dependency
statement is load-bearing: a reviewer reads it as established and reasons from
it. Prose asserting something about a corpus OUTSIDE the criterion's own test is
where an underived count survives longest, because review passes and mechanical
enforcers alike read criterion bodies hardest and that prose least.

**The derivation MUST test the proposition the sentence asserts.** A citation
that resolves proves its target exists; it does not prove the claim made about
that target. Confirming a range begins where it says it begins does not test the
word "full". Derive the predicate, not the pointer.

**A zero carries a control proving the pattern CAN match.** `grep -c` counts
LINES, not entries; a malformed pattern, a wrong path, and a genuine absence all
return the same zero. Report the count and the control together. Check 12 in
`steps/gate-validation.md` requires this of gate evidence rows; this rule
requires it wherever a number is authored.

**A corrected number puts every artifact stating it inside the blast radius.**
When a repair changes a count, an upstream artifact carrying the same count is
in scope for that repair, not outside it.

**A prescriptive count is not an assertion.** A number specifying what an
implementation or a test MUST do is a requirement and derives nothing. This rule
binds descriptive counts: claims about what a corpus already contains.

Violation is a MAJOR adversary finding and a `code-reviewer` finding.
