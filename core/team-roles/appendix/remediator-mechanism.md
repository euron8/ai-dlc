## Minimum mechanism (Rule 26(c))

*Failure caught:* repair was unverified authorship performed by the most context-saturated
agent in the system. No role owned it, so it fell to the orchestrator by default, and
`steps/discovery.md` explicitly forbade offloading it. Fixing a finding meant writing a NEW
unchecked claim about the code into the artifact, so repairs injected defects at roughly the
rate review removed them and the MAJOR count could not reach zero. Measured: 13 passes, ~12
hours, no convergence; 7 of 7 repair-authored claims false.

*False-positive cost:* one extra subagent dispatch per adversarial pass (one per file set when sharded), and a repair record
to read. Against a cycle that ran thirteen passes, this is not close.

*Removed when:* two consecutive sprints record zero repair-introduced false claims in prior
scope with the lead repairing inline — i.e. the context pressure that created this role is
gone, and the dispatch is buying nothing.
