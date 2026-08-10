---
paths:
  - "docs/plans/**"
---

<!-- no-stub: work on a plan begins by reading `docs/plans/<slug>.md`, so the trigger
     fires before the first edit. The one case that reads nothing first -- PROMOTING a
     new plan into docs/plans/ -- is covered because validate-plan-shape.sh gates it at
     push, which is a mechanism rather than a pointer. -->

# A plan that must survive the session lives in `docs/plans/`

Plan mode writes to `~/.claude/plans/`, outside the repo, where nothing can check it and
nobody else can read it. The moment a plan becomes a handoff — the thing a later session
is told to READ and FOLLOW — promote it to `docs/plans/<slug>.md` and commit it. Then it
is reviewable in the PR that does the work, and `scripts/validate-plan-shape.sh` holds it
to a shape a stranger can act on.

The shape, and the reason for each part, measured on this repo's first plan at the moment
it was handed off:

- **`## Start here`**, naming the repos and the read/write boundary. Without a declared
  entry point a resuming session acts on whichever section it reads first.
- **A numbered next-action list**, blocked items marked as blocked. A plan that records
  state and never says what to do next is a report.
- **One current status record.** It had two, and the older one predated a release; a
  superseded section is fine, but it has to say so where the reader is, not elsewhere.
- **Completed work marked completed.** Two release sections still read as work to do
  after they had merged. A session told to FOLLOW the file would have redone them.
- **Citations that resolve.** `path:line` is this repo's evidence form, and one that
  cannot be located at resume time is a promissory note against evidence.
- **An operator-ping instruction.** The plan is executed by a session the operator cannot see,
  where "still working" and "stopped, waiting on you" look identical from outside — so silence
  is a stall found only by polling. Every plan tells its executor to ping on any question, on
  any decision, and on completion (including an early stop). Measured across this repo's own
  runs: every consumer-session stall ended with the operator asking rather than the session
  reporting, including one sitting on a blocking question and one that had already FINISHED.
- **A done-when whose PASS you have CHECKED IS REACHABLE.** See [[plan-shape-measured]] for
  the two measured failures that produced this clause and the observation-point rule.

None of that is about writing quality. Each one makes the file produce WRONG WORK when
followed literally, which is the only thing a handoff is for.

The opt-out rule — "an instruction that ships its own opt-out is not an instruction" —
also binds every plan written here, but it is NOT restated in this file. It stays in
`CLAUDE.md` because it governs the authoring of `CLAUDE.md` itself as well as
`docs/plans/`, and a rule scoped to `docs/plans/**` cannot fire for the other half of its
own scope.
