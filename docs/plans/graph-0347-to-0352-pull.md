# SPENT — pull graph `0.347.0` to `0.353.0`. IT RAN, IN TWO LEGS, AND IT MERGED. DO NOT EXECUTE THIS.

**DISCHARGED 2026-08-11.** The consumer's #914 (`reconcile 0.348.0 → 0.353.0`) is on its main and
the pull is complete. It ran in two legs — #911/#912 reached `0.348.0`, #913 filed two candidates
and stopped by operator direction, and #914 finished the range after core took them.

**Verified from this side rather than accepted:**

- All four stamp fields read `0.353.0 / 6e6598a`, which is distribution `main` exactly.
- 9 of 9 shipped non-fixture files are byte-identical to the distribution. Control: the same
  comparison against those files at `b502b68` reports DIFF, so it can distinguish.
- Both retirements landed — the self-scheduling and pending-approvals sections are gone from
  `extensions/steps-domain/SKILL-push.md`, and the control section (Rule 919) is still there.
- `absorbed-specifics-survive` shipped and reports `PASS` on the consumer, which is what licensed
  those two deletions. The `.dist-only` batteries correctly did not arrive, against a control of
  156 fixtures installed.
- All four answered ledger entries carry `ADOPTED UPSTREAM (v0.351.0 | v0.352.0 | v0.353.0,
  verified 2026-08-11)` and have rotated to the archive; the live ledger shrank 3927 → 3766 lines.
- `PC-S330` is still open and unannotated, as this file directed.

**What the run produced that this file did not predict**, which is the most valuable half:
one new filing, `PC-S302-FIXTURE-SUITE-POOL-PRODUCES-AN-UNREPRODUCIBLE-FAIL-AND-THE-EVIDENCE-IS-
DELETED-WITH-THE-TEMP-DIR`. The 16-way pre-push pool reported `FAIL apply-drift-refile`, the same
fixture then passed alone and the identical re-push went green with no change to the tree — and
the pool `rm -rf`s each worker's captured output, so the only surviving artifact was the one-line
`FAIL`. The ask is narrow and is not about the flake: persist a red unit's output to a durable
path before the temp dir is removed, and name that path in the `BLOCKED` line. Note **I66** binds
the runner to be one program across both pre-push hooks, so any fix lands in both.

**One prediction this file got wrong, in its own favour.** It told the executor to expect the
self-update and the reconcile as separate PRs. The run produced a single PR (#914) and advanced
all four stamp fields, so both halves ran. The "machinery pair did not move" finding-condition was
correctly not triggered.

Original text follows, unedited.

---

# EXECUTE THIS in a graph session — RESUME the stopped pull, now `0.348.0` to `0.353.0`

You stopped this pull at `0.348.0` by operator direction, after filing two push candidates. Core
has taken both. This file is the same runbook, updated for where you actually are.

## Start here

**Repos and the boundary.** Work in `/Users/n8/git/graph` (the consumer). Read
`/Users/n8/git/ai-dlc` (the distribution) if you need to see what is incoming, but **do not edit
it** and do not commit there. Every command below runs in the consumer unless it says otherwise.

**PING THE OPERATOR on any question, on any decision this file does not already make, and on
completion — including an early stop.** From outside, a session that is thinking and a session
that is waiting on a human look identical, and every stall in this program's history ended with
the operator asking rather than the session reporting, including one that had already finished.

**THE FILENAME SAYS `0347-to-0352` AND THE RANGE NOW STARTS AT `0.348.0` AND ENDS AT `0.353.0`.
It is not renamed per release** — a renamed handoff breaks every link to it mid-run, and this file
is linked from your own stop commit. Read the range from the status table, never from the
filename.

**EVERY FIGURE HERE IS A DATED MEASUREMENT**, re-taken 2026-08-10 after your stop, against
consumer `a928010e1` and the distribution branch carrying v0.353.0. Where a paragraph names a
command, that command is the evidence. Re-derive before acting on one.

**Take the target sha from `origin/main` at your run, not from this file.** The figures below are
invariant under the squash that lands v0.353.0; the sha is not.

**`apply.sh` is only the MECHANICAL half.** You are running `/ai-dlc-update`, which runs the
self-update first and then the reconcile. Expect all four stamp fields to advance. A run where
`version`/`commit` moved and `skill_version`/`skill_commit` did not means only the mechanical half
ran — that is a finding, not a normal outcome.

**This runbook is SPENT once the pull merges.** Say so in its own title then. A discharged runbook
still titled EXECUTE THIS is how a later session redoes a landed pull.

## Current status — one record, and it is the only one in this file

| | |
|---|---|
| your stamp, all four fields | `0.348.0 / b502b68` — re-read it, do not trust this row |
| your HEAD | `a928010e1`, branch `ai-dlc/feature/s302-position-usd-create-position` |
| your working tree | 5 dirty lines, all under `_bmad-output/` telemetry |
| distribution target | `0.353.0` at `origin/main` |
| releases remaining in range | v0.349.0 (#516), v0.350.0 (#518), v0.351.0 (#519), v0.352.0 (#520), v0.353.0 |
| files changed in range | 28 total |
| **shipped** files | **14**, derived: 18 under `core/`, minus 4 sitting in `.dist-only` fixture directories |
| non-`core/` control | 10 — `VERSION`, `CHANGELOG.md`, `scripts/`, `docs/plans/`. None ship. A zero here would mean the filter was broken, not that the range was small |
| rulebook files in range | **2** — `core/skills/ai-dlc/SKILL.md` and `core/skills/ai-dlc/core-manifest.md` |
| `contract_version` | **18 to 18**; `layer-contract.yaml` is not in the range at all |
| your pause flag | **PRESENT** — see action 1 |
| layer report | `1 error(s), 2 warning(s)`, measured on both sides of the pull and unchanged by it |

## IF YOU ARE RESUMING MID-RUN — read this before anything else

**What already happened, and none of it needs redoing.** Your #911 (self-update) and #912
(reconcile) landed `0.347.0 → 0.348.0`, and #913 filed two push candidates and stopped the pull by
operator direction. All four of your stamp fields read `0.348.0 / b502b68`, which is a complete
hop, not a partial one. **Do not re-run the 0.347.0 hop and do not re-file those two entries.**

**Both entries you filed are now answered upstream, in v0.353.0.** Core no longer states that the
sprint-PR merge cannot be a gate, and core now carries the three self-scheduling specifics your
extension held. Both of your `verify:` receipts were checked against both refs before this file
shipped — each reads one way at your installed `b502b68` and the other way at the target — so
`ledger-reverify` will close both without a hand edit.

**Because they are answered, the two `EXTENSION-TITLE-MATCHES-CORE` rows are now RETIREMENTS
rather than dilemmas.** That is the outcome both filings asked for. See action 6.

**One correction to what the earlier revision of this file told you.** It gave the range as
`0.347.0 → 0.352.0` from base `611bbe2`, and set the pause flag aside as a step it could not
measure. Your base is now `b502b68` and the range is `0.349.0 → 0.353.0`. The pause flag is still
live and still yours to clear.

## The numbered action list

1. **Clear the pause flag, or this run denies its own first dispatch.**
   `_bmad-output/pipeline-paused.flag` is present on your tree right now. Read the operator
   message it stands for first. If one is genuinely outstanding, deal with it and stop here. If it
   is residue from the S302 handoff or from your own stop, `rm -f
   _bmad-output/pipeline-paused.flag` and proceed. Bash is never denied while paused, precisely so
   this is always possible.

2. **Run the dry run.** `/ai-dlc-update` with no arguments. Read the report; do not apply yet.

3. **Run the self-update gate and do what it says.**
   `reconcile/self-update-gate.sh <dist> <base> <theirs> <consumer>`, with `base` the `commit`
   field of your stamp, `b502b68`. **This range changes two rulebook files, so its DEFER arms can
   genuinely fire here** — unlike the last two ranges, where they could not. **Quote its verdict in
   your report.**

4. **Apply.** `/ai-dlc-update apply`, then merge as usual. One version per branch does not apply
   to you: this is a pull, not a release cut.

5. **Work the `WORKLIST` rows.** The rehearsal of the wider range produced 5, all
   `extension-reread` or `extension-title-match` against
   `extensions/steps-domain/SKILL-push.md`, `SKILL-domain.md` and `party-mode-inline-relay.md`,
   and zero `DECISION` rows. Your count may differ now that the base moved; read your own run.

6. **Retire the two duplicated sections from
   `extensions/steps-domain/SKILL-push.md`.** Both are now true duplicates of core, and Rule
   27(c) forbids keeping a restatement:

   - *Pending operator approvals do not transfer across handoff* — core now scopes its sprint-PR
     exclusion to core as shipped and states outright that a project whose deploy policy defines
     the procedure has the gate **and needs no extension to say so**. Your `CLAUDE.md` Rule (b)
     and `deploy-validate.md` Step 2a are that procedure. Delete the section.
   - *No self-scheduling skill re-entry* — core now carries all three specifics your copy held.
     Delete the section.

   **Before deleting either, confirm core actually carries the replacement on YOUR tree**, after
   the apply, not on the distribution: `bash tests/fixtures/absorbed-specifics-survive/run.sh`.
   That fixture ships in this range for exactly this reason — it is what protects the deletion.

7. **Re-run every done-when below against merged main, not against the branch.**

8. **Record the ledger dispositions.** Four entries close in this range. The two from your stop
   commit close on their own receipts, quoted above. The two from before it are:

   ```
   verify: theirs_has core/hooks/ai-dlc-acknowledge.sh "pipeline-snapshot-history.md"
   verify: theirs_lacks core/skills/ai-dlc-update/reconcile/apply.sh "--theirs \"$THEIRS\" >/dev/null 2>&1"
   ```

9. **Leave `PC-S330` open, and say in your report that you did.** It is unfixed upstream. Silence
   about it would read as closure.

10. **Ping the operator with the outcome**: PR numbers, all four stamp fields, each done-when's
    actual output, whether both retirements in action 6 landed, and **anything this file predicted
    that did not happen**. The last one is the most valuable thing you can send back.

## What this range carries

- **v0.349.0** gave Rule 23 a carrier; the measurement inverted the design planned for it.
- **v0.350.0** removed a version floor that guarded `install.sh` and nothing else. **This one is
  about you**: `install.sh` is only the path a NEW consumer takes, and you arrive through
  `apply.sh`, which knew nothing about versions. Replaced by one always-on detector at use time.
- **v0.351.0** adds the fourth pause-flag carve-out so a Rule 25(a) trim can move superseded
  snapshot prose to `pipeline-snapshot-history.md` while paused. Your filing. It also ships a
  battery proving each carve-out is load-bearing, after one of the three existing arms turned out
  to be deletable with the whole suite staying green.
- **v0.352.0** stops `apply.sh` claiming catalog relabels and re-stamps it did not perform. Your
  `PC-S332`, plus the sweep its own "did NOT verify" note asked for, which found the `restamp` arm
  in the same class.
- **v0.353.0** is both entries from your stop commit. Core's sprint-PR exclusion is scoped to core
  as shipped, and the three self-scheduling specifics are absorbed with the retro lead-conduct
  finding bound to Check A and Check B's existing mechanism.

## What to expect, and what would be a finding

- **`bash tests/fixtures/absorbed-specifics-survive/run.sh` reports `PASS` after the apply.**
  This is the precondition for action 6. **If it does not, do NOT delete either extension section**
  — that is the one case where retiring your copy loses content, which is the whole reason the
  fixture ships. Report it instead.

- **NO `RESOLVED relabel` row in your apply manifest.** Your catalog is clean, so v0.352.0
  correctly says nothing. Before that fix the same run printed
  `RESOLVED relabel ext-check collisions labelled`. **If you still see that row, the fix did not
  land.**

- **The self-update gate may DEFER, and that is not a failure.** Two rulebook files are in range.
  Quote the verdict and follow it.

- **The layer report stays at `1 error(s), 2 warning(s)`.** Measured on both sides of the wider
  pull and identical. The error is pre-existing and not in this range — **do not open it as new**.
  A move is the finding.

- **After action 6, the two `EXTENSION-TITLE-MATCHES-CORE` rows for `SKILL-push.md` should stop
  appearing** on the next drift run. If one persists after the deletion, the retirement did not
  take and the report will tell you which title still matches.

- **Four `.dist-only` batteries in this range must NOT arrive**:
  `pause-write-allowlist-mutants`, `claude-rules-joins`, `shipped-rule-version-floor`, and any
  other directory carrying a `.dist-only` marker. Check with a control — count what DID install —
  because an "absent" reading over a tree where nothing installed proves nothing.

- **No adjudication count is predicted.** The last pull predicted one and produced three.

## Done-when — every criterion has been RUN, and both of its outcomes checked

1. **All four stamp fields read `0.353.0 / <merged sha>`.**
   `sed -n '1,4p' .claude/.ai-dlc-version`. **Observation point: after the merge, not after the
   apply.**

2. **`bash tests/fixtures/absorbed-specifics-survive/run.sh` reports `PASS`.** Reachable in both
   directions and both arms were run upstream before this file shipped: against `SKILL.md` at
   `9365681` all six claims report `LOST` with the control still green; against v0.353.0 it is
   `PASS`. **Observation point: after the apply and BEFORE action 6** — the fixture is what
   licenses the deletion, so reading it afterwards answers the wrong question.

3. **A paused `Edit` to `_bmad-output/pipeline-snapshot-history.md` is ALLOWED, and a paused
   `Write` to `_bmad-output/planning-artifacts/product-brief.md` is still DENIED.** Both arms were
   run on a clone of your tree: at `0.347.0` the history file read `DENY`, and after the pull it
   reads `ALLOW` with `product-brief.md` and an `Agent` dispatch both still `DENY`. **Run it
   before the apply as well as after.**

4. **`bash tests/fixtures/divergence-hard-block/run.sh` reports `PASS`**, carrying 27 assertions
   rather than the 25 you have today.

5. **`bash tests/fixtures/apply-relabel-noop-row/run.sh` reports `PASS`** — 8 ok / 0 FAIL,
   measured in your layout. **This fixture ships WITH its fix, so there is no before-arm to run on
   your tree**; its red was established upstream against `apply.sh` at `c92d509`. Do not report a
   missing red as a problem.

6. **`bash tests/fixtures/apply-machinery-stamp/run.sh` reports `PASS`** — 22 ok / 0 FAIL, three
   more assertions than today.

7. **Your full pre-push suite is green**, driven by the hook rather than a hand-rolled loop.
   `git push` is the cheapest way to run it. A `for d in tests/fixtures/*/` loop FABRICATES
   failures — several fixtures resolve the project root from the process working directory.

8. **Both sections named in action 6 are gone from `extensions/steps-domain/SKILL-push.md`**, and
   the file's remaining sections still lint clean.

## Deliberately out of scope

**`PC-S330` is still open upstream.** `ledger-rotate.sh` scopes its unarchivable-set phrase test
to the entry BODY while `ledger-reverify.sh` scopes its skip to the entry TITLE, so the two
disagree about which entries are closed and the report states the reverify behaviour as its
premise. It gets its own release; leave the entry as it stands.

**Two `apply.sh` arms of the same class as `PC-S332` remain.** `RESOLVED consistent` is now gated
on the re-stamp landing but still verifies no file CONTENTS against theirs; and `drift-refile`
discards the exit status of its `known-skills.json` merge. Both are named in v0.352.0's CHANGELOG
so they are visible rather than implied-fixed.

**The wider companion-file sweep.** Your acknowledge-hook filing noted it covered only the one
pairing hit live, and that a full sweep of live/archive pairs against the pause allowlist is a
separate, larger filing. It has not been done. The allowlist now has four arms, each proven
load-bearing, but the SET is still whatever the four cover.
