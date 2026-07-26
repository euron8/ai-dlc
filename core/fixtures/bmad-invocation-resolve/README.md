# bmad-invocation-resolve

Drives `validate-bmad-invocations.sh` (gate-validation Check 32).

The defect this guards is a BMAD skill name that resolves as a *directory* while
loading nothing: `SKILL.md` is a one-line loader for a path in a module layout
BMAD has abandoned. A directory-existence check passes on it. Both name families
exist upstream and differ by one word, so a pipeline can invoke the dead one
indefinitely while the live equivalent sits beside it.

Everything here is synthetic. The real consumer's live skills are all
self-contained, so the load-target arm of the check cannot be exercised against
them — the shim shape has to be constructed.
