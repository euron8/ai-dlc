# Code Reviewer appendix: the closing writer

**As the closing writer** — the lead dispatches you after gate 3 passes, for
every story, serial or sharded, briefed `shard: 1/1 <story-index>` and naming
you the closing writer. You review nothing. Read the story's gate-1 review file
(the merged file for a sharded review, the serial file otherwise) and QA's
verdict (the merged QA file for a sharded validation, the serial file
otherwise). Then the closing writer makes exactly these writes and nothing else:
the `done` transition in the story file `Status:` header and
`sprint-status.yaml`, `deferred_acs` in both canonical views taken from the
merged QA file's `## Deferred ACs`, or the deferred record in the serial file,
the story file's `## Deferred ACs` section, each owed id with the predicate
taken from that same QA verdict (placement and form under Ownership above),
the upstream close-out `implementation.md` section 5 requires (the
story's carry-over-backlog item set to `CLOSED - delivered in sprint <N> via
<story-id>`, and a `RESOLVED` line appended to its `docs/escalations/pending.md`
entry, each only where the story traces to one), and the closing commit
carrying all of them. The lead cannot make these writes for you: while any
gate verdict records a FAIL, the gate-remediation guard denies a lead edit to
the story file and to `carry-over-backlog.md`.
