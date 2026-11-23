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
taken from that same QA verdict (placement and form below),
the upstream close-out `implementation.md` section 5 requires (the
story's carry-over-backlog item set to `CLOSED - delivered in sprint <N> via
<story-id>`, and a `RESOLVED` line appended to its `docs/escalations/pending.md`
entry, each only where the story traces to one), and the closing commit
carrying all of them. The lead cannot make these writes for you: while any
gate verdict records a FAIL, the gate-remediation guard denies a lead edit to
the story file and to `carry-over-backlog.md`.

- The closing writer owns the **`done` transition**: the closing writer writes
  `status: done` to `sprint-status.yaml` and the story file `Status:` header, in
  the closing commit. Dev owns the earlier `status: review` write (`dev.md`); QA verifies
  the two files match and rejects on mismatch. Three roles write this file by
  design — the transitions are what separate them.
- **With `done` the closing writer writes the story's `deferred_acs`, in BOTH canonical views**
  (`_bmad-output/implementation-artifacts/sprint-status.yaml` and
  `_bmad-output/planning-artifacts/sprint-status.yaml`): the id of every AC for
  which QA's verdict recorded a deferral predicate (`qa.md` "Deferred-AC
  discharge predicate"), as ONE single-line list — `deferred_acs: [AC5, AC6]`.
  If the story has no deferred AC, the closing writer writes `deferred_acs: []`. Never a block list
  and never a list wrapped over two lines: `sprint-status.sh check-stories`
  reports either as a FINDING and `close` refuses on it. deploy-validate §4b
  clears the ids; `close` refuses the sprint while any remain.
  At `done` the closing writer also writes a `## Deferred ACs` section into the story file.
  Each entry opens with `- **<id>**`, the IDENTICAL string written to `deferred_acs`,
  and carries that AC's predicate text copied from the verdict file the gate-2 check read
  (the latest-pass QA verdict (the highest `-p<N>`, or the unsuffixed file when there is only pass 1), which the closing writer reads), and cites that verdict path.
  A story with no deferred AC gets the section with body `None.`.
  The section sits directly BEFORE `## Dev Agent Record`;
  in a story with no Dev Agent Record it is the last `## ` section, above any provenance block.
  deploy-validate §4b reads each owed predicate from that section.
