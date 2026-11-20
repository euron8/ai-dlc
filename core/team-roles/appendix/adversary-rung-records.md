**Minimum mechanism (Rule 26(c)).** *Catches:* the ladder had no rung for a
correct-but-over-built artifact, so a removal finding had nowhere to live and drifted
out of the graded set entirely — ungraded, invisible to Check 24, landing only if the
lead happened to read the prose. *False-positive cost:* a MAJOR filed on taste forces
another pass, and an extra pass is where new CRITICALs come from — the three-part bar
is the guard. *Removed when:* two consecutive sprints file zero over-engineering MAJORs
and the retro finds no shipped unrequested mechanism, or the lead overrides them as
taste twice running — either way the rung is not discriminating.

**Minimum mechanism (Rule 26(c)).** *Catches:* the repair step is unverified
authorship. Fixing a finding means writing a NEW claim about the code into the
artifact, and nothing checked it until the next pass, one cycle later — so repairs
injected defects at roughly the rate review removed them and the MAJOR count could not
reach zero. Measured: a cycle ran thirteen passes without converging, and **every**
prior-scope finding across its last five passes was a false claim introduced by a repair. *False-positive cost:* a MAJOR on a claim that happens to be true but is
written without its derivation — which is the point: the cost of deriving it is one
command, and the cost of not deriving it is a full pass. *Removed when:* two consecutive
sprints record zero repair-introduced false claims in prior scope.

**Minimum mechanism (Rule 26(c)).** *Catches:* an attribution with no citable message
treated as a locked requirement, so a later pass grades the work against a requirement
nobody stated. *False-positive cost:* a MAJOR on a genuine attribution whose author
omitted the locator, repaired by adding one line. *Removed when:* a mechanism verifies
operator attributions against the session record before the pass is dispatched.

**Minimum mechanism (Rule 26(c)).** *Catches:* work proceeding to deploy-validate on an
authorization whose premise no longer holds, without the operator being asked again.
*False-positive cost:* a MAJOR on an outcome that changed in a way the authorization
did not depend on, dismissed by citing the authorization's text. *Removed when:*
authorizations record their premises in a form a gate can join against later events.

**Minimum mechanism (Rule 26(c)).** *Catches:* an AC asserted that the set of durable-marker
prefixes written by one module had exactly one member, and carried the recipe that settles
it. Three consecutive passes read that recipe and accepted it — one of them affirmatively
cleared it by name, on a true-but-narrower premise standing in for the broader claim. The
fourth ran it: **19 write sites, 17 distinct prefixes**, against a tree none of the first
three had modified. The AC's own paired control was unexecuted too, and was dead —
unconditionally true against 19 real sites, discriminating nothing. *False-positive cost:*
running a recipe that turns out to be correct costs one command; not running it costs a
full pass, and the pass after that reviews whatever the repair wrote instead.
*Removed when:* the recipes are executed by machinery before the pass is dispatched, so a
false claim cannot reach a reviewer to be read-and-believed.

**Minimum mechanism (Rule 26(c)).** *Catches:* a rebind that changed which input counted as
which side re-keyed a hardcoded threshold into a different unit. Two architecture passes and a
code review each confirmed the branch order and passed it; the threshold's worth rose by about
six orders of magnitude with no diff touching it, and a skipped leg of a locked requirement
shipped reporting success. *False-positive cost:* one derivation per keyed literal per binding;
a rebind that keys no literal costs one sentence and the command that showed it. *Removed
when:* a mechanism enumerates the literals a re-bound value flows into, and prices them, before
the pass is dispatched.
