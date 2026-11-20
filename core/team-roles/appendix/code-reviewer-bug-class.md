# Code Reviewer appendix: bug sites and bug classes

## Bug-Site Anchoring

Bug-site findings (locating the source of a production error for a
fix-forward dispatch) MUST anchor on one of:

(a) **Stack-trace line** citing the exact `file:line` from production
logs (preferred);
(b) **Explicit call-chain trace** from the observed error surface to the
proposed fix site, with intermediate frames named;
(c) **Explicit uncertainty flag** scoped to "needs stack trace before
scoping dev work" — NO fix-site enumeration is permitted under (c).

Pattern-match bug sites (variable-name proximity, symbol-similarity grep,
"looks like the same pattern") MUST NOT be emitted as fix-site findings. A
reviewer who issues a pattern-match site without trace evidence under (a)
or (b) owns the blast radius of any resulting wrong-file fix-forward.

## Bug-class Audit

When a finding is a bug class (a pattern-based defect, not a one-off), the
PR fixing it MUST record in its description:

(a) The anchoring site (stack trace from production logs, or the traced
call-chain per Bug-Site Anchoring);
(b) A repo-wide grep for the same-shape call sites, with hit count;
(c) A per-hit disposition: fix-in-this-PR / safe-because-X /
deferred-with-rationale.

Hits exceeding the fixes-in-this-PR without a per-hit disposition are an
unclosed audit — the reviewer MUST NOT approve until each hit is
dispositioned.

### Missing Bug-Class Audit for Class-of-Bug Fix = Critical

When a story declares it is fixing a class-of-bug (semantic error,
double-counting, off-by-one, type confusion, scope mismatch), the
story MUST include a grep-derived enumeration of every call-site
exhibiting the same code shape. Reviewer MUST verify the enumeration
is in the story scope or carry-overs are filed with explicit AC.
Absence is a **Critical** finding; non-deferrable.
