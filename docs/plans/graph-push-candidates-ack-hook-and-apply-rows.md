# EXECUTE THIS — two push candidates from the graph consumer, proven on a clone, handed off as a runbook

Two entries from the reference consumer's push-candidate ledger, each re-verified against this
repository rather than against its CHANGELOG, plus the runbook that carries the resulting range
back to that consumer. This file is the program record; the runbook is a separate deliverable
named below.

## Start here

**Repos and the boundary.** Work in `/Users/n8/git/ai-dlc` (the distribution). The consumer
`/Users/n8/git/graph` is READ-ONLY for the whole of this program — read it to derive a figure,
**do not edit it**, do not commit in it, and do not push from it. Its push-candidate ledger is
the consumer's own record and is not ours to annotate; the CHANGELOG is the channel it reads on
its next reconcile.

**PING THE OPERATOR on any question, on any decision this file does not already make, and on
completion — including an early stop.** From outside, a session that is thinking and a session
that is waiting on a human look identical, and every stall in this program's history ended with
the operator asking rather than the session reporting.

**Nothing ships on unit-level green.** v0.349.0 shipped a version floor tested three ways, all
passing, that protected nothing: `install.sh` is only the path a NEW consumer takes, and an
existing one arrives through `apply.sh`. The defect was found by driving a real pull against a
disposable clone of the consumer. Every release in this program is proven the same way before
it is pushed. The clone recipe and its safety assertion are in the rehearsal section.

**Every figure here is a dated measurement**, taken 2026-08-10 against distribution `c92d509`
and consumer `ae1b73de0`. Where a paragraph names a command, that command is the evidence.
Re-derive before acting on one.

## Current status — one record, and it is the only one in this file

| | |
|---|---|
| consumer stamp | `0.347.0 / 611bbe2`, read from `.claude/.ai-dlc-version` |
| consumer HEAD | `ae1b73de0` on `ai-dlc/feature/s302-position-usd-create-position` |
| consumer dirty lines | **6** — the baseline the rehearsal asserts before and after every run |
| distribution at program start | `0.350.0` / `c92d509`, and local `main` level with `origin/main` |
| ledger entries in scope | 2 of the 3 open: the 2026-08-10 acknowledge-hook filing, and `PC-S332` |
| ledger entries deliberately left open | 1: `PC-S330` |
| release for the acknowledge hook | **v0.351.0** — code complete, rehearsal outstanding |
| release for the apply-manifest rows | **v0.352.0** — not started |
| the runbook | `docs/plans/graph-0347-to-0352-pull.md` — not started; ships with the second release |

## The numbered action list

1. **Land v0.351.0.** The fourth carve-out in `core/hooks/ai-dlc-acknowledge.sh`, the two
   positive arms in `core/fixtures/divergence-hard-block/run.sh`, and the new
   `core/fixtures/pause-write-allowlist-mutants/` battery. Cut the branch from `origin/main`,
   one version per branch — a squash of two versions takes the first version in the subject and
   breaks the release triple.

2. **Rehearse v0.351.0 on a clone before pushing it**, per the rehearsal section. Report the
   before/after verdict pair for `pipeline-snapshot-history.md` and the unchanged dirty-line
   count on the original.

3. **Land v0.352.0.** The relabel row and the restamp row in
   `core/skills/ai-dlc-update/reconcile/apply.sh`, the new `apply-relabel-noop-row` fixture, and
   the extension to `apply-machinery-stamp`. Its CHANGELOG entry names the two arms in the same
   class this release does NOT fix, so a reader cannot take the sweep for complete.

4. **Rehearse the full range on a fresh clone**, `0.347.0` through `0.352.0`, end to end. Every
   figure the runbook publishes comes from this run and from nowhere else.

5. **Write `docs/plans/graph-0347-to-0352-pull.md`** and land it with the second release. Its
   required shape and content are in the runbook section below.

6. **Ping the operator with the outcome**, including anything this file predicted that did not
   happen. That last item is the most valuable thing to send back — the previous runbooks were
   each wrong about something only the consumer's tree could show.

## What the two entries are, and what verifying them added

**The acknowledge hook's pause-flag allowlist was one file short.**
`core/hooks/ai-dlc-acknowledge.sh` allows a write to `_bmad-output/pipeline-snapshot.md` while
the Rule 29 pause flag is up. Its companion `pipeline-snapshot-history.md` fell through to the
catch-all and was denied. Rule 25(a) in `core/skills/ai-dlc/SKILL.md:1103` and Check 14's `trim`
remedy in `core/skills/ai-dlc/steps/gate-validation.md:877` both prescribe MOVING superseded
snapshot prose into exactly that file, so the rulebook mandated a write the hook denied. Hit
live on the consumer at a handoff seam, which is precisely where a trim comes due.

**Verifying it added a finding the entry did not carry: the allowlist was unasserted as a set.**
No fixture and no validator bounded its membership. Arm 1, the updater's own scratch space, had
zero coverage anywhere — it could be deleted whole and the entire suite stayed green. A fourth
arm added without a mechanism is a fourth arm nobody can distinguish from a comment, which is
why this release ships a battery rather than a one-line patch.

**`apply.sh` prints a completed-work row for work that did not happen.** Its catalog-relabel arm
invokes `relabel-extension-checks.sh` with output discarded and branches on exit status, and
that tool exits zero both on a successful relabel and on a tree with nothing to label. The row
prints either way. Step 7 of `core/skills/ai-dlc-update/SKILL.md:1045` instructs the reader not
to re-do a `RESOLVED` row by hand, and `core/skills/ai-dlc-update/SKILL.md:1032` names catalog
relabels in that legend specifically, so the row the reader is told to trust is the one that can
be false.

**Verifying it added the generalization the entry explicitly did not make.** Fifteen arms emit
`RESOLVED`; three of them prove nothing. The relabel arm is the filed one. The `restamp` arm is
guarded only by the stamp file existing, and its two writes are `sed` calls whose status is
discarded — while its sibling `restamp-machinery` re-reads the written bytes and compares them,
for exactly this reason, stated in its own comment. The fix stopped one branch short. The
`consistent` arm asserts the tree matches a sha and checks nothing.

## What is in each release

**v0.351.0** adds one literal `case` arm for `pipeline-snapshot-history.md`, placed beside the
arm for the file it archives so the pairing is visible in one screen. It is literal rather than
a `pipeline-snapshot*.md` glob: the glob would also admit the timestamped archive form and
anything later named to match, and no denial has ever been measured against those — the archive
form is produced by a move at fresh start, and Bash is deliberately never denied while paused.

It also closes the coverage hole. `core/fixtures/divergence-hard-block/run.sh` gains a positive
arm for the new file and one for the updater scratch space that shipped with no fixture at all.
`core/fixtures/pause-write-allowlist-mutants/` is a new distribution-only battery that deletes
each carve-out in turn from a copy of the hook and asserts the deletion turns exactly its own
path from allow to deny, moving no other; widens one arm to prove the negative is falsifiable;
and joins to the shipped fixture on names, so an arm proven load-bearing here but unnamed there
is reported rather than silently uncovered. Measured: 0.9s solo against a suite pole near 447s.

**v0.352.0** captures the relabel invocation's output and branches on the count it already
prints, emitting a row with a subject when work occurred and nothing when it did not. It applies
the read-back guard to the `restamp` arm, copied from the sibling arm that already has it. It
adds a fixture driving the real `apply.sh` over a zero-collision consumer — no existing fixture
does, which is the absence that let the defect ship — and extends `apply-machinery-stamp` with
the stamp-missing-its-fields case.

The `consistent` arm and the unguarded half of `drift-refile` stay open, and the second
release's CHANGELOG entry says so. Making the `consistent` row true needs a verification pass,
which is a separate release rather than a guard swap.

## The rehearsal, and the assertion that protects the consumer

Clone the consumer rather than touching it. `file://` forces a real copy, so nothing in the
clone can reach back into the original, and a shallow single-branch clone is 226M of a 4.9G
tree:

```sh
git clone --depth 1 --no-hardlinks \
  --branch ai-dlc/feature/s302-position-usd-create-position \
  file:///Users/n8/git/graph "$SCRATCH/graph-copy"
```

**Assert `git -C /Users/n8/git/graph status --porcelain | wc -l` before and after every run.**
The baseline is 6. A rehearsal that changed it has written to a tree this program is forbidden
to write to, and that is a stop-and-ping condition rather than something to clean up quietly.

Drive the real copier with `apply.sh <dist> <base> <consumer> <theirs>`, taking `<base>` from
the consumer's own stamp. Run each release's probe against the clone BEFORE the apply as well as
after: a probe seen only green cannot tell a fix from a no-op. For the first release the probe
pair is a write to `pipeline-snapshot-history.md` under a live pause flag, which must move from
denied to allowed, and a write to a plain planning artifact, which must stay denied. For the
second it is the apply manifest over the consumer's already-clean catalog, where the relabel row
must stop appearing.

**`apply.sh` is only the mechanical half.** Hook registration in the consumer's `settings.json`
is a separate step, `reconcile/settings-merge.sh`, whose template must be materialized to a real
path first. Neither release adds a new hook, so zero new registrations is the correct reading
here and not a second defect.

## The runbook this program owes the operator

`docs/plans/graph-0347-to-0352-pull.md`, landed with the second release, following the house
outline of the pull runbooks already in this directory: a `## Start here` carrying the repo
boundary and the ping mandate, one current-status record, a numbered action list, what the range
carries, what to expect paired with what would be a finding, a done-when whose every criterion
has been run in both directions, and a deliberately-out-of-scope section.

Content this range requires: the consumer's stamp re-read rather than trusted; the five releases
in the range with a derived shipped-file count and a stated non-`core/` control; the pause flag,
which the consumer's own handoff left live and which the first action must clear or the run
denies its own first dispatch; mechanisable `verify:` receipts for the two entries this program
closes; and an explicit statement that the third entry remains open, so its silence is not read
as closure.

Two shape rules the done-when section must honour, both learned from runbooks in this directory.
A criterion whose subject the run itself consumes states its observation point — before which
step, against which ref — because a criterion checked after its own subject is rotated away
correctly reads zero. And a criterion must be reachable at the moment it is READ, not only at
the moment it was written.

**This runbook is SPENT once the pull merges.** Say so in its own title then. A discharged
runbook still titled EXECUTE THIS is how a later session redoes a landed pull, and every other
file in this directory is discharged today.

## Done-when

1. **Both releases are on `origin/main`**, each cut from `origin/main` and each carrying one
   version. Check with `git ls-remote --heads origin`, not by reading a push log — a push piped
   through `tail` truncates the suite output, and a short log reads as a suite that never ran.

2. **`bash core/fixtures/pause-write-allowlist-mutants/run.sh` reports `PASS` from the repo
   root.** Reachable in both directions and both were run before this file was written: against
   the hook without the fourth arm it reports `8 assertion(s) FAILED`, including a control that
   refuses to read the baseline and a join arm naming the uncovered updater carve-out; with the
   arm and the two fixture assertions it reports `PASS`.

3. **`bash core/fixtures/divergence-hard-block/run.sh` reports `PASS`**, carrying two more
   assertions than it did at `c92d509`.

4. **The full pre-push suite is green**, driven by the hook rather than a hand-rolled loop.
   `git push` is the cheapest way to run it. A loop that changes directory per fixture
   FABRICATES failures: several fixtures resolve the repo root from the process working
   directory.

5. **The suite pole has not moved.** Compare the top of `.git/ai-dlc-fixture-durations` before
   and after. The new battery measured 0.9s solo against a pole near 447s, so it must not appear
   near the top; if it does, the decision to seed inline rather than reuse the sibling seed was
   wrong.

6. **`bash scripts/validate-plan-shape.sh` reports `0 error(s)`** over every file in this
   directory, this one and the runbook included. Run it after the code lands, because its
   citation arm resolves `path:line` against current line counts and both releases move lines in
   files this program cites.

7. **The consumer is byte-identical to where it started.** `git -C /Users/n8/git/graph status
   --porcelain | wc -l` reads 6, and `git -C /Users/n8/git/graph rev-parse HEAD` reads
   `ae1b73de0`. The pull itself is the operator's to run, from the runbook, in their own session.

## Deliberately out of scope

**`PC-S330`** — `ledger-rotate.sh` scopes its unarchivable-set phrase test to the entry BODY
while `ledger-reverify.sh` scopes its skip to the entry TITLE, so the two tools disagree about
which entries are closed and the report states the reverify behaviour as its premise. A third
subsystem, and it gets its own release. The runbook records it as still open.

**The `consistent` row and `drift-refile`'s unguarded merge**, both named above, both left for a
later release, both recorded in the second release's CHANGELOG so the consumer sees them.
