# EXECUTE THIS in a graph session — pull the consumer from `0.347.0` to `0.352.0`

Five releases, two of which close entries this consumer itself filed. The whole range was driven
end to end on a disposable clone before this file was written, and every figure below is a
reading from that run.

## Start here

**Repos and the boundary.** Work in `/Users/n8/git/graph` (the consumer). Read
`/Users/n8/git/ai-dlc` (the distribution) if you need to see what is incoming, but **do not edit
it** and do not commit there. Every command below runs in the consumer unless it says otherwise.

**PING THE OPERATOR on any question, on any decision this file does not already make, and on
completion — including an early stop.** From outside, a session that is thinking and a session
that is waiting on a human look identical, and every stall in this program's history ended with
the operator asking rather than the session reporting, including one that had already finished.

**EVERY FIGURE HERE IS A DATED MEASUREMENT**, taken 2026-08-10 against consumer `ae1b73de0` and
distribution `4345b1d` — the pre-squash branch commit — on a shallow clone of this repository:

```sh
git clone --depth 1 --no-hardlinks \
  --branch ai-dlc/feature/s302-position-usd-create-position \
  file:///Users/n8/git/graph "$SCRATCH/graph-full"
```

`file://` forces a real copy, so nothing in the clone can reach back. **Your repository was never
written to**: `git status --porcelain | wc -l` read 6 before and after every run, and HEAD stayed
`ae1b73de0`. Where a paragraph names a command, that command is the evidence and the number
beside it is a reading. Re-derive before acting on one.

**THE REHEARSAL DROVE `apply.sh` DIRECTLY, WHICH IS ONLY THE MECHANICAL HALF.** You are running
`/ai-dlc-update`, which runs the self-update first and then the reconcile. That is why the
rehearsal's stamp shows `skill_version`/`skill_commit` still at `0.347.0 / 611bbe2` while
`version`/`commit` advanced — the machinery pair moves in the step the rehearsal did not run, not
in the one it did. Expect all four fields to advance on your run.

**This runbook is SPENT once the pull merges.** Say so in its own title when it is; a discharged
runbook still titled EXECUTE THIS is how a later session redoes a landed pull, and every other
file in the distribution's `docs/plans/` is already discharged.

## Current status — one record, and it is the only one in this file

| | |
|---|---|
| your stamp, all four fields | `0.347.0 / 611bbe2` |
| distribution `VERSION` / target | `0.352.0` at `origin/main`. **Take the sha from `origin/main` at your run, not from this file** — the rehearsal drove the pre-merge branch commit `4345b1d`, and the squash that lands it mints a different sha. Every figure below is invariant under that; the sha is not |
| releases in range | v0.348.0 (#515), v0.349.0 (#516), v0.350.0 (#518), v0.351.0 (#519), v0.352.0 |
| files changed in range | 36 total |
| **shipped** files | **13**, derived: 19 under `core/`, minus 6 sitting in `.dist-only` fixture directories |
| non-`core/` control | 17 — `VERSION`, `CHANGELOG.md`, `CLAUDE.md`, `.githooks/pre-push`, `scripts/`, `docs/plans/`, `.claude/rules/`. None ship. A zero here would have meant the filter was broken, not that the range was small |
| rulebook files in range | **2** — `core/skills/ai-dlc/SKILL.md` and `core/skills/ai-dlc/core-manifest.md` |
| `contract_version` | **18 to 18**; `layer-contract.yaml` is not in the range at all (0 files) |
| your pause flag | **PRESENT** and untracked — see action 1 |
| layer report, before and after | `1 error(s), 2 warning(s)`, unchanged by this range |

Re-read your own stamp rather than trusting row one:
`sed -n '1,4p' .claude/.ai-dlc-version`.

## The numbered action list

1. **Clear the pause flag, or this run denies its own first dispatch.** Your
   `_bmad-output/pipeline-paused.flag` is live. It is UNTRACKED, which is why the rehearsal clone
   did not carry it and could not exercise this for you — the rehearsal ran unpaused, so this
   step is the one thing below that was reasoned rather than measured on your tree. Read the
   operator message the flag stands for first. If one is genuinely outstanding, deal with it and
   stop here; the pull is not urgent enough to talk over a human. If it is residue from the S302
   handoff, which is the usual case, `rm -f _bmad-output/pipeline-paused.flag` and proceed. Bash
   is never denied while paused, precisely so this is always possible.

2. **Run the dry run.** `/ai-dlc-update` with no arguments. Read the report; do not apply yet.

3. **Run the self-update gate and do what it says.**
   `reconcile/self-update-gate.sh <dist> <base> <theirs> <consumer>`, with `base` the `commit`
   field of your stamp, `611bbe2`. This range changes two rulebook files, so its DEFER arms can
   fire — that is a reason to expect an answer, not a reason to skip the question. **Quote its
   verdict in your report.**

4. **Apply.** `/ai-dlc-update apply`, then merge as usual. One version per branch does not apply
   to you: this is a pull, not a release cut.

5. **Work the five `WORKLIST` rows.** The rehearsal produced exactly these, and no `DECISION`
   rows at all:

   | rows | subject |
   |---|---|
   | 3 × `extension-reread` | `party-mode-inline-relay.md`, `SKILL-domain.md`, `SKILL-push.md` |
   | 2 × `extension-title-match` | `SKILL-push.md` |

6. **Re-run every done-when below against merged main, not against the branch.** The adjudication
   digest covers the entry, so a run that looked clean on the branch can be blocked on main.

7. **Record the two ledger dispositions.** Both are mechanisable, and both receipts were checked
   in BOTH directions against the two refs before this file shipped — each one reads 0 at your
   installed commit and non-zero at theirs, or the reverse:

   ```
   verify: theirs_has core/hooks/ai-dlc-acknowledge.sh "pipeline-snapshot-history.md"
   verify: theirs_lacks core/skills/ai-dlc-update/reconcile/apply.sh "--theirs \"$THEIRS\" >/dev/null 2>&1"
   ```

   The first closes your 2026-08-10 acknowledge-hook filing. The second closes `PC-S332`.

8. **Leave `PC-S330` open, and say in your report that you did.** It is unfixed upstream — see
   the out-of-scope section. Silence about it would read as closure.

9. **Ping the operator with the outcome**: the PR numbers, all four stamp fields, each
   done-when's actual output, and anything this file predicted that did not happen. **The last is
   the most valuable thing you can send back** — the previous runbooks were each wrong about
   something only your tree could show, and both times the correction became a distribution
   release.

## What this range carries

- **v0.348.0** moved this repository's own path-scoped authoring rules into `.claude/rules/` and
  measured the loader: it memoizes per session, so a scoped rule loads once, on the first
  matching read, and an `Edit` fires it transitively.
- **v0.349.0** gave Rule 23 a carrier, and the measurement inverted the design that had been
  planned for it.
- **v0.350.0** removed a version floor that guarded `install.sh` and nothing else. **This one is
  about you**: `install.sh` is only the path a NEW consumer takes, and you arrive through
  `apply.sh`, which knew nothing about versions. The replacement is a single always-on detector
  at use time rather than a gate at each copy site.
- **v0.351.0** adds the fourth carve-out to the pause-flag write allowlist, so a Rule 25(a) trim
  can move superseded snapshot prose into `pipeline-snapshot-history.md` while paused. Your
  filing. It also ships a battery proving each carve-out is load-bearing, after finding that one
  of the three existing arms could be deleted whole with the entire suite staying green.
- **v0.352.0** stops `apply.sh` claiming catalog relabels and re-stamps it did not perform. Your
  `PC-S332`, plus the sweep its own "what I did NOT verify" note asked for, which found the
  `restamp` arm in the same class.

## What to expect, and what would be a finding

- **NO `RESOLVED relabel` row in your apply manifest.** Measured on a clone of your tree: your
  catalog is clean, so v0.352.0 correctly says nothing. Before the fix the same run printed
  `RESOLVED relabel ext-check collisions labelled`. **If you still see that row, the fix did not
  land — quote it.**

- **The manifest should be 15 `RESOLVED`, 5 `WORKLIST`, 1 `NOTE`, and zero `DECISION`.** A
  `DECISION` row is not a failure, but it is work this file did not predict. **Report any.**

- **All four stamp fields reach `0.352.0` and the merged sha.** The rehearsal reached `0.352.0 /
  4345b1d` on `version`/`commit` and left the machinery pair behind because it ran only the
  mechanical half. **Yours runs both, so a machinery pair still reading `0.347.0` after a full
  `/ai-dlc-update apply` IS a finding.**

- **The layer report stays at `1 error(s), 2 warning(s)`.** Stated as a criterion because a move
  is the finding, not because a pass is interesting. **Measured on BOTH sides**: the same
  `1 error(s), 2 warning(s)` before the pull at `0.347.0` and after it at `0.352.0`. The error is
  pre-existing and this range does not touch it — do not open it as new.

- **Three `.dist-only` batteries in this range must NOT arrive**:
  `pause-write-allowlist-mutants`, `claude-rules-joins`, `shipped-rule-version-floor`. Verified
  absent on the pulled clone, with 123 shipped fixtures present as the control — an "absent"
  reading over a tree where nothing installed proves nothing. **If one appears in
  `tests/fixtures/`, report it: it edits copies of core's own sources and cannot pass on your
  tree.**

- **No adjudication count is predicted.** The last pull predicted one and produced three.
  Predicting an adjudication count is the same class of error as predicting a hop count. Read
  what your run says.

## Done-when — every criterion has been RUN, and both of its outcomes checked

1. **All four stamp fields read `0.352.0 / <merged sha>`.**
   `sed -n '1,4p' .claude/.ai-dlc-version`. **Observation point: AFTER the merge, not after the
   apply** — see the machinery-pair note in Start here.

2. **A paused `Edit` to `_bmad-output/pipeline-snapshot-history.md` is ALLOWED, and a paused
   `Write` to `_bmad-output/planning-artifacts/product-brief.md` is still DENIED.** Both arms run
   on a clone of your tree, driving your own installed hook: at `0.347.0` the history file read
   `DENY` and the snapshot read `ALLOW` — your filed defect, reproduced — and after the pull the
   history file reads `ALLOW` with `product-brief.md` still `DENY` and an `Agent` dispatch still
   `DENY`. **Run it before the pull as well as after**; you have only ever seen its red, so its
   green is the half still owed.

3. **`bash tests/fixtures/divergence-hard-block/run.sh` reports `PASS`**, carrying 27 assertions
   rather than the 25 you have today. Run from the project root. Measured at 27 ok / 0 FAIL on
   the pulled clone in your layout.

4. **`bash tests/fixtures/apply-relabel-noop-row/run.sh` reports `PASS`** — 8 ok / 0 FAIL,
   measured in your layout. **This fixture ships WITH its fix, so there is no before-arm to run
   on your tree**; its red was established upstream instead, by driving it against `apply.sh` at
   `c92d509`, where the clean-catalog assertion fails. Do not report a missing red as a problem.

5. **`bash tests/fixtures/apply-machinery-stamp/run.sh` reports `PASS`** — 22 ok / 0 FAIL, three
   more assertions than today, covering the rulebook half of the re-stamp.

6. **Your full pre-push suite is green**, driven by the hook rather than a hand-rolled loop.
   `git push` is the cheapest way to run it. A `for d in tests/fixtures/*/` loop FABRICATES
   failures — several fixtures resolve the project root from the process working directory, and
   four of them print `FIXTURE BROKEN`, which reads exactly like a regression in the pull.

7. **The layer report reads `1 error(s), 2 warning(s)`**, per the expectation above. This is an
   asserted NO-CHANGE with both sides measured.

## Deliberately out of scope

**`PC-S330` is still open upstream.** `ledger-rotate.sh` scopes its unarchivable-set phrase test
to the entry BODY while `ledger-reverify.sh` scopes its skip to the entry TITLE, so the two
disagree about which entries are closed and the report states the reverify behaviour as its
premise. Not fixed in this range. It gets its own release; leave the entry as it stands.

**Two `apply.sh` arms of the same class as `PC-S332` remain.** `RESOLVED consistent` is now gated
on the re-stamp actually landing, but still verifies no file CONTENTS against theirs; and
`drift-refile` discards the exit status of its `known-skills.json` merge, so a failure there
still reaches a `RESOLVED` row. Both are named in v0.352.0's CHANGELOG entry so they are visible
rather than implied-fixed, and both need more than a guard swap.

**Your own S302 sprint work.** This pull touches the distribution's machinery, not your sprint.
If the pull and the sprint contend for the same files, stop and ping rather than merging through.
