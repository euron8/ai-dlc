# Carry-over backlog

Items this repo owes itself. An entry lives here when it is real, measured, and **not the
subject of any live plan** — the state that previously had no home, so it survived only by
being written into a plan about something else and vanished when that plan was discharged.

**This is the DISTRIBUTION's backlog, and it is not a push-candidate ledger.** A consumer's
`_bmad-output/ai-dlc-update/push-candidate-ledger.md` tracks what that consumer wants pushed
UPSTREAM to ai-dlc, and its receipts resolve against a pull's `theirs` ref with the verbs
`theirs_has` / `theirs_lacks`. This file tracks what ai-dlc owes ITSELF, its receipts resolve
against this working tree, and its verbs are `sh` / `has` / `lacks`. The two grammars are
mutually unreadable by each other's engine on purpose. Entry ids are `BL-`, never `PC-`.

**Read by** `scripts/backlog-reverify.sh`, which executes each entry's `verify:` receipt and
emits a status. **Rotated by** `scripts/backlog-rotate.sh`, which moves closed entries to
`docs/backlog.archive.md` — it moves, it never deletes. Neither ships; both are
distribution-only, as `core/fixtures/plan-shape/.dist-only` already is.

## Receipts

```
verify: sh <one-liner>              exit 0 = the fix is present -> CLOSE-CANDIDATE
                                    exit 9 = the receipt cannot measure its subject -> NEEDS-REVIEW
                                    any other non-zero = still reproduces -> STILL-LIVE
verify: has   <repo-rel-path> "<substr>"    close when the file CONTAINS the substring
verify: lacks <repo-rel-path> "<substr>"    close when the file LACKS it
verify: manual                      no mechanical predicate by design -> HAND-REVIEW
```

**Prefer `sh`.** The tree is right here and executable, which the consumer's ledger cannot
assume of the ref it greps. A receipt runs from the repo root with stdin closed, so it names
any input it reads as a file. A behavioural predicate asserts the defect itself and cannot be
anchored on prose the author invented to describe a wanted fix.

**THIS FILE'S `sh` POLARITY IS THE OPPOSITE OF THE CONSUMER LEDGER'S, AND THE TWO ARE WRITTEN
IN THE SAME SESSIONS.** Here, `scripts/backlog-reverify.sh:241-250` reads **exit 0 as "the fix
is present"** and non-zero as "still reproduces". In a consumer's push-candidate ledger,
`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:942` reads it the other way — **exit 0
means the entry STILL REPRODUCES**, and non-zero proposes CLOSE-CANDIDATE. Carrying this file's
rule into a consumer receipt writes a predicate that proposes closing a LIVE defect, which is
the one direction that loses data permanently. Check which file your receipt lands in before
you fix its polarity, and read the emitter rather than either header.

**In a consumer receipt, guard the unresolvable subject too.** A RENAMED subject also exits
non-zero there, so a relocation reads as an absorption that never happened; `[ -n "$s" ] ||
exit 127` makes it NEEDS-REVIEW instead. This file's engine needs no such guard, because its
non-zero direction is the one that keeps the entry open.

**When you must use `has`/`lacks`, anchor on a token the fix CANNOT BE WRITTEN WITHOUT** — a
flag, a path, a function name — never a phrase describing the fix. The consumer's engine
detects that error by reading a third ref; this one has no third ref to read, so the rule is
enforced by the author and by review, not by the tool. `core/fixtures/ledger-reverify-unfalsifiable/README.md`
is the measurement: 13 entries on the reference consumer carried predicates that could never
have gone green, and would have reported "still open" forever.

**A closed entry is annotated in place and left for rotation**, in the form
`**LANDED (v<version>, verified <sha>).**` — the annotation FORM is what the rotator keys on,
never the word anywhere in prose, because an entry that merely discusses landing something is
not a closed entry.

## BL-230 — `reconcile-emit-report`'s kill-set arms fail intermittently under the pool — E1, E8 and E9 all measured, on three different worlds — and E1's success message describes a different assertion than the one it makes

**PARTIAL IN v0.669.0: THE FIXTURE'S OWN FOUR `<( )` READS ARE STAGED.** The A3a/A3b control and
sandbox renders, CONTROL(T) and B2's diagnostic `diff` each render to a staged file whose exit status is
read; a non-zero status prints `FIXTURE BROKEN — … exited N`. Healthy runs byte-identical (3 base, 3 tip).
Forced, not sampled: an EBADF on the section read put 3 FAILs at base blaming the copy and 0 at tip; a
sandbox render exiting 3 scored A3a `ok` at base and `FIXTURE BROKEN` at tip. **This does not close the
entry**: none of the recorded extra-world shapes came from these four sites, and the kill-set arms never
used `<( )`. Citations moved: E1 is at `run.sh:2336` on 0.668.0 (not `:1129`), E8 `:2377`, `v_render`
`:1718`, the RAW-lines arm `:2294`, each shifting further with this release. Non-comment
`core/fixtures/*/run.sh` lines containing `<(` number 75 across 26 files (comment lines
included, the same glob reads 93; derived with `grep -n '<(' core/fixtures/*/run.sh`, dropping
lines whose first non-blank character is `#`). They are not all live process substitutions: 34 of the 75
sit in `procsub-staged-refusal` and `procsub-staged-refusal-boot`, 17 each, most of them as
mutation strings that seed the defect. So a lint cannot ship yet, and it would need to tell
those strings from real reads before it could.

**Found 2026-09-11** during batch 85, when E1 failed a gate run on a branch whose change cannot
reach it. Two separate defects in one arm; the second is what makes the first expensive.

**E8 IS THE THIRD ARM, MEASURED AT BATCH 138 UNDER A SIX-WIDE POOL.** `v_kill E8 "V-R V-U"`
(`run.sh:1596`) failed a gate run whose tree changes only `ai-dlc-handoff-pending.sh`,
`ai-dlc-continue.sh` and `pipeline-state-paths.json`. Attribution severed in one invocation: the
fixture names those three files **0**, **0** and **0** times against a control of **22** for
`emit-report.sh`. Solo from the repo root the same tree exits **0** at 83 assertions with 0
failures, and the very next pool run at the same width scored it `ok`. So the population is
arms scored under pool contention at ANY width, not a property of 12-way, and E8 sits between
the two arms already named — the entry's own reading of its subject reproduces at a third site.

**THE FLAKE.** `v_kill E1 "V-R V-U"` (`run.sh:1129`) asserts a mutant moves EXACTLY two worlds. On
one 12-way pool run it reported `[V-R V-U V-HC]` and failed; the same tree run solo from the repo
root passes with E1 green, and a second pool run passed. **It is not caused by the change that was
in flight**: `reconcile-emit-report` never executes `apply.sh` — `grep -cE 'bash .*apply\.sh|\$APPLY'`
returns **0** against a control of **24** in `apply-restamp-worklist` — and its scorer
(`v_render`, `:614`) calls `emit-report.sh` alone. The causal path from the branch's two new
`say WORKLIST` sites to the region V-HC edits is severed.

**WIDER THAN FILED: E9 FAILS THE SAME WAY, ON A DIFFERENT WORLD, AND SO DOES AN ARM THAT IS NOT A
KILL-SET AT ALL.** Measured at batch 114, which this arm charged for a second time. Gate run 1
PASSED the fixture suite and gate run 2 failed `v_kill E9` on a **byte-identical tree** — same tree
sha `b36117f5`, the two commits differing only in squash topology — and a third run passed. E9's
expected set is `[V-R V-N V-H V-HA V-S V-U V-HC]` and it reported `[V-R V-N V-B V-H V-HA V-S V-U
V-HC]`: the extra world was **V-B**, not the V-HC this entry predicts, though both arms score
through the same `v_kill`/`v_diffset` whole-world set difference. Separately, four copies of the
fixture run in parallel from **unmodified `origin/main`** put 1 of 4 red on a THIRD arm — the
docs-only-move `--verify` assertion, which is not a kill set — against 3 green in the same
invocation. So the population is "arms scored under pool contention", not "E1", and the entry's
own title understated it.

**THE ATTRIBUTION WAS MEASURED, NOT ASSUMED, AND IT COST THE BATCH A FULL GATE CYCLE.**
`reconcile-emit-report` seeds **0** `verify: theirs_has` and **0** `verify: sh` receipts — only
three `theirs_maybe`, which no arm of `ledger-reverify.sh` dispatches (control: an impossible verb
also 0) — so the batch-114 change to that engine's `sh` arm renders no row in this fixture in
either revision, and `unseen_rows()` keeps both spellings of the row it renames in any case. The
causal path is severed for the same KIND of reason it was severed at batch 85, by a different
mechanism.

**WHY V-HC IS THE PLAUSIBLE UNSTABLE MEMBER.** `v_kill` scores by whole-world set difference, so one
world with an unstable score pollutes the set. V-HC is built by deleting the first
`^HARD-UNREGISTERED-CORE-DRIFT` line from a rendered region, and the arm beside it at `:1102` exists
because *"the difference is being taken over RAW lines"* is its known failure mode. The fixture's own
`CONTROL(V)` arm already anticipates slot-dependent instability here, in as many words: the control
and shipped copies *"were computed in different parallel slots, so it is also the arm that would
catch the scoring racing with itself."*

**THE SECOND DEFECT, AND IT IS THE ONE WITH A RECEIPT.** E1's success message reads *"the THREE
worlds that read 3 go red and no other"* while its assertion passes `"V-R V-U"` — **two**. Derived:
the assertion set has 2 members, the message says three. One of them is wrong, and a reader
debugging a failure reads the message. This is `verification-discipline.md`'s "text about a program
is not the program", inside an arm whose whole subject is set membership.

**WHY THIS IS FILED RATHER THAN FIXED HERE.** The two defects have different owners. The message/
assertion mismatch is a one-line correction, but WHICH one is wrong is not derivable from the arm —
it needs whoever knows whether a third world should be in that set, and if one should, the arm has
been under-asserting since it was written. The flake needs the pool to reproduce and may be a
property of `v_diffset` rather than of E1.

**The cost is misattribution, and it was nearly paid.** A gate-green branch was blocked by this arm
and the first hypothesis was that the change caused it. Two measurements and an adversarial pass
were spent proving otherwise. **An intermittent arm on a shared fixture charges its cost to whichever
change happens to be in flight**, which is the failure this entry exists to stop repeating.

**Receipt limits, stated.** The receipt scores ONLY the message/assertion mismatch, because that is
the half that is mechanically checkable: it counts the worlds in E1's `v_kill` argument and refuses
while the adjacent `ok` line says "three". **It does not and cannot score the flake** — an
intermittent failure has no deterministic receipt, and a receipt that ran the fixture once would
report green on the common case. Closing this needs the mismatch fixed AND a stated finding about
the flake, and the second half is not receipt-enforceable. Exit 9 if the arm or its message is gone.

**WIDENED AT BATCH 116, AND THE WIDENING CARRIES A LEAD.** Two hands hit the flake independently
on a gate-green branch whose change cannot reach it, and one reproduced it at `49e5356d`
(`origin/main`, none of that batch's code): pooled over both hands, tip 0 of 48 red and base 1 of
48, with the other hand's separate rounds at roughly 2 in 60. At that rate 48 runs expects 0.5
events, so neither clean sweep discriminates and neither is reported as absence. Two surfaces, both
in the FALSE direction — assertion 1 (`--verify failed a correct report`, a sound report accused of
being stale) and the E9 mutant (`the kill is unattributed`) — two arms on two trees, which argues
one shared cause. Ruled out so nobody repeats it: 48 concurrent `--verify` runs against one stored
report went 0 red with a serial control at rc=0 in the same invocation, and 12 concurrent renders
gave one md5, so neither `render()` nor `--verify` alone is the moving part. The lead is already in
the tree: `ledger-reverify.sh:1089-1096` records this exact class as measured on a busy host and
fixed it by prefixing its own temp dirs, while `emit-report.sh:331` and `:373` still call bare
`mktemp`. Not folded into `v0.582.0`, whose subject was the step 3b section; the pre-existing
intermittent charged to whichever change is in flight is the shape this entry exists to stop.

**A FOURTH ARM AT BATCH 136, AND IT IS `E3` — AN ARM THIS ENTRY DOES NOT NAME.** Two full gate runs
on the same branch, minutes apart, differing only by one integer pair on a `.githooks/pre-push`
argument line: run 1 scored `reconcile-emit-report` **ok**, run 2 scored it **FAIL** on
`E3 moved the worlds [V-N V-HC] and had to move exactly [V-N]`. The same tree run SOLO from the
repo root exits **0** with **0** failing assertions. Attribution severed the same way as the three
before it, derived in one invocation: the fixture names `ai-dlc-update/SKILL.md` — the only engine
file this batch changed — **0** times, against a control of **22** for `emit-report.sh`, and
`classify-block.md` **0** times. The extra world is **V-HC** again, as E1 predicted and E9 did not,
which is a third distinct expected-set for one shared cause. The entry's own generalisation from
batch 114 — the population is "arms scored under pool contention", not any named arm — now has four
members across three arms, and **E1/E9 in the title remain an enumeration where the finding is a
class.**

**A FIFTH MEASURED ARM AT BATCH 144, AND IT IS `E2`.** Filed by the consumer as
`PC-S313-EMIT-REPORT-E2-IS-A-FOURTH-POOL-FLAKE-ARM` during its 0.623.0 → 0.624.0 self-update. Its id
says fourth; counted against this entry it is the fifth, after E1, E8, E9 and E3. The consumer's
pre-push under a **6-wide** pool failed `E2 moved the worlds [V-M V-HC] and had to move exactly
[V-M]`. On the same tree, 3 standalone runs, 6 concurrent standalone copies and a full 185-fixture
12-way pool all passed. The extra world is **V-HC** again, and it is the extra world in three of the
five arms.

**CPU LOAD DID NOT REPRODUCE IT, AND THAT ZERO CANNOT DISCRIMINATE.** Batch 144 ran 144 direct
`--verify` runs, 12 fixture runs and 3432 replayed score cells, and every one agreed. At the
observed rate of about 1 in 30, 12 fixture runs predict about 0.4 failures, so a clean sweep there
is what the hypothesis predicts and refutes nothing.

**A FORCED PROCESS CAP DID FLIP THE SHIPPED PROGRAM'S VERDICT.** Under `ulimit -u`, V-HC's verdict
changed in **4 of 12** rounds. The cause was a sibling fork failure (exit 128) that was rendered as
DETECTOR-REFUSED. In one of those rounds a RETIRE-CANDIDATE row was silently dropped. So the scorer
has a real failure mode in which resource exhaustion reads as a verdict. **This is not attributed
to the consumer's failure.** One fixture run peaks about 63 processes above a baseline of about 600,
against a limit of 10666, so the consumer's run was nowhere near the cap.

**RELEASE 0.625.0 SHIPS THE INSTRUMENT.** When a kill-set arm fails, it now prints the
score cells of each world that differs and a diff of that world's stderr, so the next pool failure
carries its own cause.

**ITS FIRST CATCH NAMED A MECHANISM, AND 0.625.0 FIXES IT.** An unforced E2 failure, in a scratch
copy with no `.git`, showed V-HC's `HARD-UNREGISTERED-CORE-DRIFT schemas/thing.json` rendered as
`CORE-TEMPLATE-SUBSTITUTED` with NO DETECTOR-REFUSED line. So that extra world was not the `ulimit`
refusal above. `unregistered-drift.sh`'s `is_unregistered()` fed `diff ... 2>/dev/null` into an
awk whose END printed "clean" on no hunk, and it is reached only after `cmp` shows the files differ.
Forced with a `diff` shim that exits 2: unshimmed HARD, shimmed CORE-TEMPLATE-SUBSTITUTED. A second
site, `closest_ancestor_blob()`, scored a failed diff as a perfect match: unshimmed HARD drift,
shimmed `HARD-CORE-BEHIND`. Both now fail closed, each with an arm and a mutant in
`setup-config-drift`. **This entry stays live**: the E2/V-HC shape matches this mechanism, but E9's
extra world was V-B, and E1/E8 are not yet shown to share it. Close only when the instrument has
recorded a pool failure's cause, or a pool run of the size that predicts at least 3 failures at
base comes back clean at tip.

**E1'S SECOND DEFECT IS SETTLED.** The assertion `"V-R V-U"` is right and the message "three" was
wrong. The message is corrected in 0.625.0.

**THE RECEIPT IS RETIRED TO `manual`.** The receipt above scored only the message/assertion
mismatch. Once the message was corrected it would have proposed CLOSE on a flake that is still
live, which is the one direction that loses the entry. The flake has no mechanical predicate until
the instrument catches a failure and names its cause.

**MEASURED AT BATCH 151: THE CLOSE CONDITION'S POOL WAS RUN, AND TIP WAS NOT CLEAN.** Base is
0.624.0 (`29291758`), the release before 0.625.0. The pooled batch-116 rate of 3 in 108 predicts
3.0 failures in 108 runs. The run used 108 tip runs (`937919e4`) and 48 base runs, interleaved
two tip to one base under `xargs -P 6`, each from its worktree root. Every one of the 156 logs
carries a verdict line. Tip scored **2 red of 108** (1.9%) and base **1 of 48** (2.1%), so the
0.625.0 fix did not move the rate. The box's load average ran from 27 to 78 throughout. None of
the three reds came from the window in which a 4-wide release gate ran beside the pool.

**THE LIVE CLASS IS NOT THE KILL SETS, AND THE INSTRUMENT CANNOT REACH IT.** No red was a
kill-set arm: 0 `moved the worlds` lines, against 156 `E2 … ok` and 1716 E-arm `ok` lines as the
control. So `v_diag`, which is called only from `v_kill`, printed nothing in any log. All three
reds are the `--verify` false positive this entry recorded at batch 116. It appears as `--verify
failed a correct report` in tip.3 and base.19, and as the docs-only `--verify` arm in tip.3 and
tip.18. tip.3 also reports `ORIENTATION INVERTED` with empty labels, and every region-reading arm
fails in it. The kill-set subclass scored 0 of 108 at tip, but also 0 of 48 at base, so its clean
tip is not evidence.

**AN UNMEASURED LEAD, STATED AS ONE.** An empty orientation block in tip.3 fits a seed-time render
whose `preclassify.sh` call failed under load. `emit-report.sh:204` takes that call's result as
`2>/dev/null || true`, which yields an empty `pc`, no CLASSIFY rows and no orientation block. That
is the same fail-open shape 0.625.0 fixed for `diff`. It was not confirmed, because the fixture's
EXIT trap deletes the seed's `WORK` directory. A DIAG path for the render arms, keeping the seed's
stderr on a red, is the next instrument.

**MEASURED AT BATCH 153: THE LEAD'S MECHANISM IS REAL, AND IT WAS WIDER THAN AN EMPTY `pc`.** The
adversary forced git failures in a scratch copy with a PATH shim and under `ulimit -Su`.
`preclassify.sh` exited **0** in almost every case. A failed `diff --name-status` gave EMPTY
output. A failed `hash-object` or `rev-parse` gave WRONG buckets: a BOTH-ADDED file came out
`UPSTREAM-ONLY-ADD`, which apply overwrites. There were three causes. The main loop was the
right-hand side of a pipeline without `pipefail`, so the diff's status was lost. `file_hash` and
`blob_hash` mapped any failure to `MISSING`, which is a real bucket input. And `lib.sh`'s memo
cached the failed status, so one transient 128 was served to every later lookup in the same
render. The fix hand then compared the engines. Under `ulimit -Su` over 90 runs, the old engine
gave **22** wrong outputs at rc 0 and the new one gave **0** wrong and **13** refused. Under the
Nth-git-call shim, the old engine exited 0 in **15 of 15** runs with **6** wrong, and the new one
gave **0** wrong.

**WHAT 0.637.0 SHIPS.** `preclassify.sh` now exits 2 on any failed git call, with one stderr
line naming the call. The memo caches only a git answer, never a failure. `emit-report.sh` reads
preclassify's exit status. On a non-zero exit, or on no rows while `base..theirs` changes
`core/`, it renders `DETECTOR-REFUSED  preclassify.sh …` in all five sections built from those
rows instead of `none`. `--verify` refuses a fresh render carrying that line with cause
`PRECLASSIFY-REFUSED`. `apply.sh` stops before writing on the same two conditions, and now writes
its in-flight marker only after preclassify has classified. The fixture's render arms now print
`DIAG` lines on a red, so the next pool red carries its own cause.

**THE TIP ADVERSARY FOUND THAT THE EMPTY-RESULT REFUSAL HAD A LEGITIMATE SUBJECT.** A range whose
only `core/` change deletes a `core/scripts/*` file, pulled by a consumer still holding it at the
pre-relocation `scripts/<name>`, classified to zero rows because preclassify skipped that path
silently. The new refusal then stopped the pull in all five sections and in apply, and no re-run
could clear it. Fixed at the source: preclassify now emits a `PRE-RELOCATION-NOOP` row for the
skipped path, so an empty result means nothing was classified. `relocation-preclassify` arm G and
`apply-drift-refile` arm h each fail on the revert. It also found that the memo's temp name is
about 10 bytes longer than the cache name, so a key of roughly 244 to 253 bytes reads as git's
"absent" at rc 0. The longest real key measured is 218; `BL-306` closes that window in the next
release.

**THIS DOES NOT CONFIRM THE POOL CAUSE, AND THE ENTRY STAYS LIVE.** The forced failures show
that the mechanism exists. They do not show that the pool reaches it. One fixture run peaks at
about 63 processes against a cap of 10666, so ordinary pool load is nowhere near the `ulimit`
that forced these failures. The close condition is unchanged: the instrument records a pool
failure's cause, or a pool run of the size that predicts at least 3 failures at base comes back
clean at tip.

**MEASURED AT BATCH 155: A PARTIAL POOL, TOO SMALL TO DISCRIMINATE.** Batch 151's shape was rerun
at tip 0.639.1 (`49330f4a`) against base 0.624.0 (`29291758`), under `xargs -P 6`. The driving hand
stalled, and the pool died after 66 of 156 runs: 44 tip and 22 base. All 66 exited 0 and end in
`PASS`. No log carries a `DIAG` line, which is correct, because a `DIAG` prints only on a red. At
batch 151's rates, 22 base runs predict 0.46 failures and 44 tip runs predict 0.8. Both are below
one, so this clean result does not separate a fixed tip from an unfixed one, and it is not
evidence either way. The close condition needs the full 156, which takes about 2.5 hours at the
observed mean of 359s per run.

**MEASURED AT BATCH 160: THE FULL POOL RAN, AND THE INSTRUMENT RECORDED A RED'S CAUSE.** The pool
was 156 runs: 108 at tip `975a861c` (0.645.0) and 48 at base 0.624.0 (`29291758`), 6-wide, with
the box's load average between 20 and 30. It returned **1 red at tip and 1 at base**. Every log
carries a verdict line. There were **0** `--verify` false positives and **0** kill-set `moved the
worlds` lines, against **156** `E2 … ok` lines as the control.

**tip.32 was a kill-set red, and its `DIAG` named the world.** Mutant E3 on world V-N scored
`3|BLOCKERS-RESOLVED|1|1|4|4` where the arm expects `…|0|0`. The approval had four rows that the
fresh render did not, so `--verify` read the region as resolved blockers with unseen rows.

**THE OUTPUT WAS REPRODUCED BYTE-FOR-BYTE BY FORCING ONE FAILURE AT APPROVE TIME.** In a scratch
copy, a PATH shim made `diff` exit 2 with no output, or made the first `grep -E '^< '` of the
orientation sample fail, while V-N's approval was rendered. `emit-report.sh` then printed
`ONLY IN THEIRS: none` and `ONLY IN OURS: none` and exited 0. Scoring that approval under E3
reproduced tip.32 exactly: the same four `unseen:` rows and the same `19,22c19,20` hunk. The
unshimmed control renders `ONLY IN … (1, complete)` on both sides. The cause was the orientation
block itself. It ran `diff … || true`, which swallows diff's exit 2 along with its exit 1, then a
`grep | sed | grep … || true` chain, then `grep -c … || true` into `${n:-0}`, so every failed step
became an empty sample. A failed `git show` read as `THEIRS absent` by the same shape.

**base.2 was the same class one detector over, and 0.625.0 had already fixed it.** Its V-HB world
rendered 0 HARD copies. That is `unregistered-drift.sh`'s `is_unregistered()` scoring a failed
`diff` as clean, closed at `240d813a` (`unregistered-drift.sh:450-451` now reads the rc bare). The
same shim at tip keeps 1 HARD copy.

**WHAT 0.647.0 SHIPS.**
- The orientation block reads diff's exit status bare: 0 and 1 mean it ran, and 2 or more
  renders `DETECTOR-REFUSED  orientation diff exited <rc> for <path>` for that file.
- One `awk` replaces the `grep | sed | grep` chain and the `grep -c`. It prints the count and the
  sample from one run, and a non-zero exit or a count that is not a number refuses.
- Absence at theirs is decided by `git ls-tree`, which exits 0 with no row for an absent path.
  `git show` and `git cat-file -e` both exit 128 for an absent path and for a failed read.
- Refusals are per file, so one refused file does not blank the others. Every refusal line
  starts at column 0. `--verify` counts `^DETECTOR-REFUSED` in `refused_new`, so a verify under
  the same failure reads UNDECIDED instead of BLOCKERS-RESOLVED.
- `relabel-extension-checks.sh` has its rc read off the bare run. 0 and 1 mean it ran (1 is its
  collision finding), and 2 or more refuses.
- `retired-tokens`, `ledger-reverify`, `predicate-differential`, `retired-fixtures`,
  `retired-layer-contract` and `retired-layer-passage` each say "0 ALWAYS". Each has its rc read
  off the bare run, and a non-zero rc refuses.
- The fixture's `v_approve` treats an approved region carrying `^DETECTOR-REFUSED` as a
  transient world-build failure. It retries the approve up to 3 times and reports
  `FIXTURE BROKEN` only if every attempt refuses. The retry is legitimate only because the engine
  now names the refusal. Before this release it would have retried into a silent `none`.

Healthy renders are byte-identical to 0.646.0. Measured on the reference consumer's
`1115a426..a5cbdf0b` range: 27895 normalised bytes each side, 4 `ONLY IN` lines, 0
`DETECTOR-REFUSED` lines on either side. This was measured on the first engine commit
(`1f0a81f3`) and again on the staged-file commit (`9f153a07`). The detectors'
exit-0-with-stderr refusals are not in this release; they are filed as `BL-333`.

**THE TRIGGER IS A BASH 3.2 FD RACE, AND IT EXPLAINS E3/tip.32.** Under concurrent
`/bin/bash` 3.2.57 workers, `diff <(printf …) file` exits 2 with `diff: /dev/fd/63: Bad file
descriptor`. Three hands measured it independently at about 0.15-0.4% under 4 concurrent
workers (3 and 8 in 2000 in two of the runs). The temp-file spelling measured 0 in 2000 in the
same loop. `reconcile-emit-report`'s `v_par` runs 4 scorers at once, which is how an approval
picked up a spontaneous orientation refusal. So the failure behind tip.32 was not load. It was
this race hitting the orientation `diff`, which then rendered `none`.

0.647.0 removes `<( )` from the five verdict-bearing reconcile diff sites. Each input is staged
in a per-process `mktemp -d` file, cleaned by an EXIT handler, and `diff`'s status is read
directly:
- `emit-report.sh`: the orientation diff, and the `--verify` want/got diagnostic diff.
- `register-drift.sh`'s `substitution_only()`.
- `unregistered-drift.sh`'s `is_unregistered()`.
- `apply.sh`'s drift refile of `provenance-block.json`. That site read no status before, and a
  failed diff there is now a DECISION row that withholds the stamp.

The staged file is PIPED into `diff -` rather than passed as a second path. That choice is for
byte-identity: Apple `diff` hunks two regular files differently from a pipe and a file (294
lines against 293 on a graph pull). A two-path diff would therefore have moved every approved
region. The piped form reproduces the old `<( )` output.

**BL-230 STAYS LIVE FOR E1, E2, E8 AND E9.** The batch-160 arm hand drove the orientation
failure at approve time on 0.646.0 against their recorded extra-world shapes (E1
`[V-R V-U V-HC]`, E2 `[V-M V-HC]`, E8 `V-R V-U`, E9 `[… V-B …]`). It did not reproduce any of
the four. Only E3 on V-N is explained by this mechanism. The fd race may reach the other
detectors' `<( )` sites, but that is not measured. The render fix's own receipt lives on
`BL-334`, because it proves the fix and not this entry's close.

verify: manual

## BL-004 — the fixtures' inner pools are owed a sweep, and the hook records them as owed

**What the figure counts, and over which set.** Per SOURCE FILE: eleven fixture `run.sh` files
open their own pool — non-comment lines matching `xargs … -P` under `core/fixtures/*/*.sh`,
excluding `consumer-suite-pool/run.sh:395`, which is a mutation string and not a pool — and
their `-P` constants sum to 70 workers (derived with `grep -nE 'xargs.*-P' core/fixtures/*/*.sh`,
dropping comment lines and that one mutation string, then summing each pool's width constant).
That is the figure `.githooks/pre-push`'s pool-width
comment cites. Per DISPATCHED DIRECTORY the set is larger: five shard directories
(`enforcement-map-derivations-b`, `enforcement-map-sites-b`/`-c`,
`layer-contract-conformance-b`, `validator-arm-selection-b`) re-enter four of those files, so
up to sixteen directories can open an inner pool on top of the outer one. Whether each shard
reaches its file's pool line was not measured. The heading's earlier "nine" and "66" were
taken over the per-source-file set before two pools were added.

Those workers sit on top of the outer pool. They cannot be swept with an environment variable —
`enforcement-map-sites` scrubs every ambient `AI_DLC_*` name for I10, and I87 binds any key a
shipped program dereferences — so sweeping them means editing the constants on a throwaway
branch that is never pushed.

The design to use: pin the dispatched set, reset the durations record from one golden copy
before every run, visit cells round-robin, and take a difference as real only where two cells'
readings do not overlap.

Carried over from `docs/plans/pre-push-wall-clock.md`, which is otherwise discharged.

verify: manual

---

## BL-005 — `validator-arm-selection` shard `b` now overlaps its seeded run with the attribution sweep; the third-directory route stays untaken

Shard `b` was a floor set by three serial units: a seeded run at 16s, an attribution sweep at
11s, and a mutant's three parallel full runs at 18s (per-block serial costs taken solo, recorded in the
timing table at the head of `core/fixtures/validator-arm-selection/run.sh`). Two routes below it
were measured: a third directory duplicating the 27s prerequisite, or overlapping the seeded run
with the attribution sweep.

**The overlap is TAKEN.** Arm 6 of that file now backgrounds exactly the two raw commands — the
seeded tree's plain validator run and `attrib` — waits each pid on its own, and reads both
statuses in the parent before any guard or assignment runs: a seeded-run exit other than 0 or 1
and a non-zero sweep exit each report FIXTURE BROKEN. The seeded run's stderr moved from the
scanned tree into the fixture's own scratch dir, so neither unit writes where the other reads.
No wall-clock gain is claimed for it: shard `b` is far from the suite's pole, so the suite's
makespan does not move. **The third-directory route stays untaken.**

**THIS ENTRY IS NOT ABOUT THE POLE, AND ITS HEADING SAID IT WAS UNTIL `v0.583.0`.** The pre-push
pole is watched by `scripts/validate-suite-pole.sh` against its tracked baseline, which is what
`BL-257` built. That validator prints a NOTE — *"the pole has moved to …; the baseline still
names …"* — when the longest unit in a run is not the one the baseline names, so the current
pole is read off that NOTE or off the top of `.git/ai-dlc-fixture-durations` (a LOADED cost),
never off a figure quoted here. Every pole figure this entry has carried went stale: the
**166s / 217s** in its old heading were displaced at **v0.541.0** by `BL-088`, four releases
before `BL-255` read the heading and found it still asserting them, and the `ledger-reverify`
figure that replaced them was itself displaced when that unit was sharded. A session scoping
performance work off this entry optimizes a fixture that is not the pole; shard `b`'s floor is
a real and separate subject, and it is the only subject this entry has.

Carried over from `docs/plans/pre-push-wall-clock.md`. This is a program, not a single fix.

verify: manual

---

## BL-007 — the audit-anchor chain is a 1-deep link, so an old gap is permanently invisible

`--prior-sprint-sha` computes `prior = current - 1` and exact-matches it
(`core/scripts/validate-audit-anchors.sh`). There is no contiguity assertion anywhere in the
anchor path — control: monotonicity language exists elsewhere in the corpus
(`core/scripts/validate-spec-join.sh` "non-monotonic; ids must ascend and never renumber"), so
the grep that found none in this path was working.

Consequence: a gap at sprint N−1 is fatal, and a gap at N−2 or older is undetectable. Two
sprints after a hole nothing revisits it, and `retro.md` Step 5b prunes the live file to the 3
most recent entries into an archive with, in its own words, "no rendered schema region, no
validator, no budget".

Scoped OUT of the v0.372.0 close-record work on the operator's decision: that release makes a
non-retro close RECORDABLE, which is what the consumer filed. Detecting historical holes is a
different check and would fire on every consumer whose chain already has one, so it needs a
PENDING/SKIP posture for pre-migration state before it could ship.

The receipt is BEHAVIOURAL and carries its own control. It builds a chain with sprints 10 and
12 and asks for sprint 13's prior: the resolver answers 12 happily and never sees that 11 is
missing, so a zero exit there IS the defect. Asking for 12's prior on the same file exits 1,
which is the control that the resolver does fire on an N−1 absence — the two together are what
distinguish "no contiguity check" from "no check ran". An anchor on the `current - 1` source
line would have closed itself on a reformat.

**The receipt was rewritten at v0.666.0, because it demanded the posture this entry forbids.** It closed
on a NON-ZERO exit for `{10,12} -> 13`, and both callers read non-zero as "the anchor did not resolve":
Check 18 fails closed and Check 5 SKIPs. So the only fix it could accept was the gate-wedging one. The
fix reports the hole as a `PENDING — contiguity` line on stderr and leaves exit 0 and the sha on
stdout unchanged. The receipt now requires that line naming 11 with exit 0 and the sha on stdout. The
near-miss `{10,12,11} -> 13`, out of order with no hole, must carry no such line, and `12`'s prior
exiting 1 is kept as the control that the resolver still fires on an N-1 absence (exit 9 if either
control moves). Scored: exit 1 on the base resolver, exit 0 at the fix, exit 1 on a copy of the fix
with the report disabled. The scan reads the sibling `-archive.md`'s highest sprint so that a hole at
the live/archive seam is caught. Holes inside the archive are not scanned. The
`core/fixtures/check5-anchor-base` contiguity battery carries three mutants, one per property.

**Operator decision, 2026-10-01: the archive interior is not scanned.** The open half below stays
unbuilt and the entry stays live: the receipt still exits 1 and STILL-LIVE is the true reading.
The reference consumer's archive carries 13 interior holes that nothing reports.

**STILL OPEN ON ONE HALF, and the receipt is a conjunction for that reason.** Landed in 5634d7a0: a
hole below the prior sprint is reported while it sits in the live file or at the live/archive seam.
Not landed: once retro Step 5b prunes a hole past the seam into the archive INTERIOR, it becomes
invisible again, which is this entry's heading claim ("permanently invisible") in a narrower window.
The receipt's final clause seeds live `{13,14,15}` with archive `{9,10,12}` and asks for 16, requiring
11 to be named. It exits 1 today, so the entry reads STILL-LIVE. Whether to scan the archive interior
is a scope decision: the archive is contracted as "no validator, no budget", and the reference
consumer's archive today carries 13 interior holes (189, 204, 205, 239-246, 300, 301), which a
PENDING posture would print at every gate.

verify: sh t=$(mktemp -d) || exit 9; f="$t/a.md"; n="$t/n.md"; H=$(git rev-parse HEAD); printf -- '- sprint: 10\n  sha: %s\n- sprint: 12\n  sha: %s\n' "$H" "$H" > "$f"; printf -- '- sprint: 10\n  sha: %s\n- sprint: 12\n  sha: %s\n- sprint: 11\n  sha: %s\n' "$H" "$H" "$H" > "$n"; V=core/scripts/validate-audit-anchors.sh; bash "$V" --prior-sprint-sha "$f" 12 >/dev/null 2>&1; c=$?; o=$(bash "$V" --prior-sprint-sha "$f" 13 2>"$t/e"); r=$?; bash "$V" --prior-sprint-sha "$n" 13 >/dev/null 2>"$t/ne"; nr=$?; e=$(cat "$t/e"); ne=$(cat "$t/ne"); rm -rf "$t"; [ "$c" -eq 1 ] && [ "$nr" -eq 0 ] || exit 9; grep -q 'contiguity' <<<"$ne" && exit 1; [ "$r" -eq 0 ] && [ "$o" = "$H" ] && grep -q 'PENDING — contiguity: no entry for 1 sprint(s) between 10 and prior 12: 11\.' <<<"$e" || exit 1; u=$(mktemp -d) || exit 9; printf -- '- sprint: 13\n  sha: %s\n- sprint: 14\n  sha: %s\n- sprint: 15\n  sha: %s\n' "$H" "$H" "$H" > "$u/a.md"; printf -- '- sprint: 9\n  sha: %s\n- sprint: 10\n  sha: %s\n- sprint: 12\n  sha: %s\n' "$H" "$H" "$H" > "$u/a-archive.md"; ae=$(bash "$V" --prior-sprint-sha "$u/a.md" 16 2>&1 >/dev/null); rm -rf "$u"; grep -q 'PENDING — contiguity.*: 11' <<<"$ae"

---

## BL-024 — the `implementation-push` row was adjudicated and recorded, but no reconcile program reads the record

**This repo already adjudicated all five blocks of the `implementation-push` row, wrote
"recorded so the next reconciliation does not re-triage" beside the verdicts, and shipped no
reader — so the reconciliation re-triaged them.** `docs/v0.13.0-consumer-absorption-spec.md:385`
is "## 5. Explicitly NOT backported (graph-local — install would destroy these)", and `:393`
names **`done-pending-liveness`** and the **`story-status-consistency script`** inside it. `:344`
is "## 4. Tier-3 (weak / verify / heavy de-graph — likely leave)", `:346-348` reads "The 'likely
leave' assumption HELD for all five — none absorbed. Verdicts + evidence recorded so the next
reconciliation does not re-triage", and `:350-355` disposes of the mid-sprint scope re-check
trigger (`PI-S241-2`) as **LEAVE**, overlapping core's existing per-commit scope verification.
The remaining two are absorbed: `core/skills/ai-dlc/steps/implementation.md:86` is
"**Worktree-explicit dev dispatch.**" and `:225` is "**Dev-brief bug-class checklist.**", with
`:101`, `:113` and `:117` carrying the `git worktree add` base-ref and `git stash` ban verbatim.
Measured with a control in the same invocation: files under `core/` naming `done-pending-liveness`
= **0**, `validate-story-status-consistency` = **0**, `Mid-Sprint Scope Re-Check` = **0**;
`git worktree add` = **2**, `bug-class checklist` = **1**. **Nothing reads the record.** Across
the whole tracked tree, files naming `v0.13.0-consumer-absorption-spec` = **2**, and they are
`CHANGELOG.md` and `.ai-dlc-fixture-readsets.tsv` — a provenance note and a readset row, neither
a mechanism. Files under `core/` naming `consumer-absorption` = **0**, against a control of **29**
files under `core/scripts/` that name some `docs/` path, so the search can find a core-side
reference to `docs/` when one exists.

**The row's own claim is dead in every part, and the correction is that the defect is on this
side of the boundary.** Five blocks named: two absorbed, two under a standing "explicitly NOT
backported" ruling, one under a standing "LEAVE". As a push-candidate row it is a withdrawal
candidate, not a filing. What survives is an ai-dlc defect the row is evidence FOR: the
distribution keeps its absorption verdicts in a `docs/` design record marked `Status: PROPOSED`
that the reconcile machinery cannot reach, so every drain re-proposes items already refused, and
the refusal has to be re-derived by hand each time — which is what produced this entry. This is
the check-cannot-fire shape inverted: not a check that never fires, but a verdict with no
consumer.

The anchor is `consumer-absorption` under `core/skills/ai-dlc-update/`, because the fix is that
the reconcile machinery names the standing-verdict record — the join cannot be built without the
reference existing there. A tree-wide anchor was rejected on measurement: `v0.13.0-consumer-absorption-spec`
already matches two tracked files, so any receipt keyed on mere mention is satisfied by the
CHANGELOG line that recorded the spec's own creation, which is precisely an anchor on text the
fix quotes back. The control is `layer-drift` under the same subtree, which matches today, so a
mistyped path fails loudly instead of reporting a green absence.

Discharges the consumer entry `extensions/steps-domain/implementation-push.md` at pinned ledger
line 259. That row is a withdrawal candidate on its own terms; this entry is the ai-dlc-side
mechanism whose absence let it survive.

**Receipt replaced at batch 174: the old one closed on a comment.** Driven through
`scripts/backlog-reverify.sh` on a copy of the tree where
`# see docs/v0.13.0-consumer-absorption-spec.md` was appended to `reconcile/lib.sh` and
nothing else changed, it read CLOSE-CANDIDATE; on the real tree, STILL-LIVE. No behavioural
receipt can be built yet: no program drains `push_candidate` rows today (the drain is prose at
`core/skills/ai-dlc-update/SKILL.md` "Drain entries flagged `push_candidate: true`"), so there
is no output to assert on, and the old anchor assumed a fix in which `core/` cites a `docs/`
file, which the consumer boundary rules out. **What closes it:** a standing-verdict record
shipped under `core/` and read by a reconcile program that, in one run on a seeded consumer,
reports a block the record refuses as refused and a block it does not name as a push candidate.
Swap this receipt for one driving that program when it exists.


verify: manual -- no program drains push_candidate rows yet, so nothing can be driven; see above.
## BL-071 — `ledger-rotate.sh`'s split-refusal can be silenced by a body line that mentions the annotation form

**`ledger-rotate.sh`'s split-refusal can still be silenced by a body line that merely MENTIONS the
annotation form, and the two inputs that decide it are not distinguishable by any signal the
current parse computes.** `ledger-rotate.sh:196` reads `if ($0 ~ /ADOPTED UPSTREAM/ && susp_at)
susp_closed = 1` — unanchored, so a suspect whose body says "Annotate it `ADOPTED UPSTREAM
(vX.Y.Z, verified <date>)` once the grep is non-zero" scores as carrying its own close and
suppresses the refusal. The refusal exists because rotating a split entry strands its receipt in
the live ledger under no heading, which `ledger-rotate.sh:104-106` calls unrecoverable to skip.

**The obvious fix was BUILT AND MEASURED IN THE RELEASE THAT FILED THIS, AND IT WEDGES ROTATION.**
Routing this predicate through `ledger_close_awk()` — the anchored grammar lifted from
`ledger-reverify.sh`, which the same release routes three other drifted predicates through —
turns `core/fixtures/ledger-rotate/run.sh`'s own `fp-quotes` false-positive case into a refusal.
Driven on the exact ledger that arm builds, shipping rotator, sides asserted byte-different first:
unanchored **rc=0, 0 refusals**; anchored **rc=1, `REFUSING to rotate`**. A refusal writes nothing,
so that is a real entry blocked from rotating forever.

**The reason one predicate cannot serve both, which is the part worth carrying.** The stuck-set
rule and this one ask a similar question and FAIL IN OPPOSITE DIRECTIONS. The stuck rule makes a
CLAIM — these are the entries `ledger-reverify.sh` skips — so a loose form states something FALSE
about an open entry, and tightening it is strictly correct. This one SUPPRESSES a refusal, so a
loose form merely lets a split through while a TIGHT form refuses a real entry and writes nothing.

**Why the receipt below REPRODUCES rather than closes.** It exits non-zero while the colon-less
case survives, and it is expected to stay non-zero: what follows is why no predicate available
today separates that case. The colon subclass, which the parse DOES separate, is shipped (Held
note below). The two cases a fix must
separate are, on today's signals, the same shape: both are a bold bullet inside a closed entry,
both carry a receipt below them (`susp_hasv`), and the real-entry case does not even carry the
trailing colon (`susp_colon`) that would mark an annotation lead-in. The ONLY thing separating
them in the current parse is the quotation itself — the real entry quotes the annotation form
because it is discussing it, and a genuine lead-in does not quote, it IS one. That is an
accidental signal, not a designed one, and a fix needs a signal the parse does not currently
compute. A receipt asserting both arms would therefore be UNSATISFIABLE against every predicate
available today, so it would be a standard nobody can meet if it were read as a close condition.

The two cases a fix must satisfy simultaneously, so the next session does not have to rederive
them: `core/fixtures/ledger-rotate/run.sh`'s `splitter` seed must be REFUSED, and its `fp-quotes`
seed must NOT be. Both already exist in that fixture and both are already asserted.

Found while remediating `BL-035`, by that fixture, against its own author.

Held note (batch 178): the COLON subclass is closed and the entry narrows to the rest. The suppressor (now near `ledger-rotate.sh:290`) uses the archive grammar `ledger_body_archives()` when the suspect label ends in a colon (`susp_colon`, already computed) and keeps the loose `ledger_entry_line_closes()` otherwise, so a `- **Note:**` lead-in whose body only QUOTES the annotation form now refuses. A colon-titled line with a genuine bolded close still rotates, and the `fp-quotes` seed still rotates. WHAT SURVIVES: a colon-LESS suspect whose body mentions the form is still silenced, because for that label a mention and a real entry discussing the form are the same shape; the entry stays open on it. The header prose that said the consumer archive "reports 22" now says what the number counts: suspect boundary lines inside CLOSED entries, each silenced by its own close, 27 on a copy of the consumer archive at 0.674.0 (22 at the commit first measured), and 0 reported by the guard. Consumer differential, old vs new rotator: live ledger 0/0 findings and the archive 0/0, rc 0 both. Across all 144 historical live-ledger revisions the only difference is 2 revisions already refused for other lines (5eb222bb, 0def7560), which gain a `The share:` suspect in `PC-S296-WHOLE-READ-POOL` whose only silencer was an unbolded close; both rotators refuse those revisions either way. The receipt below asserts the SURVIVING subject and exits 0 only when the colon-less mention also refuses; scored under `bash -c 'set -uo pipefail; …'`: tip 3 (colon cell not refused), fix 1 (surviving cell), archive-grammar-for-every-suspect 4 (the real quoting entry refused), colon-never-silenced 5 (a genuine colon close refused).

verify: sh R=core/skills/ai-dlc-update/reconcile/ledger-rotate.sh; [ -f "$R" ] && [ -f "${R%/*}/lib.sh" ] || exit 9; D=$(mktemp -d) || exit 9; trap 'rm -rf "$D"' EXIT; H='# Push-candidate ledger\n\n- **PC-CLOSED-ABOVE** — closed\n\n  <br>**ADOPTED UPSTREAM (v0.100.0, verified 2026-01-01).** Upstream took it.\n\n'; V='  verify: theirs_has core/scripts/thing.sh "MARKER_A"\n'; Q='  Annotate it `ADOPTED UPSTREAM (vX.Y.Z, verified <date>)` once the grep is non-zero.\n\n'"$V"; printf "$H"'- **Note:** a lead-in\n\n'"$Q" > "$D/colon.md"; printf "$H"'- **A real entry that QUOTES the annotation form** in its body\n\n'"$Q" > "$D/real.md"; printf "$H"'- **Note:** a colon-titled line\n\n  **ADOPTED UPSTREAM (v0.2.0, verified 2026-01-02).** closed in its own right\n\n'"$V" > "$D/cclosed.md"; printf "$H"'- **Note** a lead-in with no colon\n\n'"$Q" > "$D/nocolon.md"; printf "$H"'- **Note:** a lead-in\n\n'"$V" > "$D/ctl.md"; ref() { o=$(bash "$R" "$1" --archive "$D/a.md" 2>&1); [ $? -ne 0 ] && grep -q 'REFUSING to rotate' <<<"$o"; }; ref "$D/ctl.md" || exit 9; ref "$D/colon.md" || exit 3; ref "$D/real.md" && exit 4; ref "$D/cclosed.md" && exit 5; ref "$D/nocolon.md" || exit 1; exit 0

## BL-128 — an override can restate a threshold that later migrates into a validator, and layer-drift cannot see it

**An `overrides/` file may restate a rule as prose; `layer-drift.sh` joins that override to the
`SKILL.md` section it shadows by `base_sha`. When the rule MIGRATES OUT of `SKILL.md` into a
shell validator, the shadowed section stops moving, the join keeps reporting `OVERRIDE-OK`, and
the override is now wrong with nothing able to say so.** No override carries a `base_sha`
against a script, so the migration is invisible to the only mechanism that watches overrides.

**Found by a peer session during the 0.443.0 pull rehearsal, on a live instance, not
hypothetically.** The reference consumer's `overrides/SKILL__Rule-8.md:31` restates arm E's
predicate: *"A nonzero MAJOR held at zero CRITICAL across 2+ passes is a STALL."* `v0.443.0`
moved arm E to `blocking > MAJOR_EXIT_CEILING`, so a plateau at 1–3 blocking MAJOR is no longer
a stall and that sentence is false. `layer-drift.sh` reported `OVERRIDE-OK` and was CORRECT to:
the `SKILL.md` section did not move. The rule did.

**The consumer-side reword is the consumer's and is NOT this entry.** This entry is the
distribution-side gap: nothing here detects an override whose subject has left the file the
override is joined to.

**Not yet scoped, and the population is unmeasured.** Two things to derive before building:
how many shipped rules have migrated from a role/skill file into a validator (the join's
blind set), and whether an override's prose can be bound to a validator at all without a
second restatement — `mechanism-design.md` warns that a rule restating a mechanism drifts
tighter than the mechanism. A detector keyed on "this override names a threshold" has an
unmeasured false-positive set and must not ship before that set is enumerated.

**Census (batch 185). Every figure below was taken over two named sets: the distribution's
`core/scripts/*.sh` at `c18897d9` (57 tracked files; `git ls-files` and `/usr/bin/find` agree), and
the reference consumer's layer at its `34f02449`, which means the 49 bodies `layer_files()` in
`layer-drift.sh` would read (9 under `overrides/` and 40 under `extensions/`, README excluded, every
body non-empty after `body_of`). These counts move with either tree, so re-derive them rather than
quote them.**

**THE MOTIVATING INSTANCE IS NOT OVERRIDE DRIFT. IT IS CORE PROSE THAT THE VALIDATOR LEFT BEHIND,
INHERITED VERBATIM.** The override's sentence (`overrides/SKILL__Rule-8.md`, body lines 25-26: "A
nonzero MAJOR held at zero CRITICAL across 2+ passes is a STALL") is byte-identical to live core
`core/skills/ai-dlc/SKILL.md:261-262`. The same predicate appears in `core/hooks/ai-dlc-acknowledge.sh:337,479`
and `core/hooks/ai-dlc-continue.sh:1012,1173`, and the consumer's installed copies of all three
carry it too. `39f0cb0b` (v0.443.0) moved arm E to `blocking > MAJOR_EXIT_CEILING` and touched
only the validator, `core/team-roles/adversary.md`, check-24 and docs, so all four core prose
sites still state the old predicate. `OVERRIDE-OK` is therefore correct in the strongest sense,
because the override matches current core. **DEFECT, not this entry's to fix: core `SKILL.md`
Rule 8 and two hook messages state a STALL predicate the validator no longer implements.** It is
filed here as a measured fact for the operator to schedule.

**(1) The migrated side.** One grep finds upper-case `NAME=<int>` assignments in the 57 files whose
name matches `CEIL|MAX|MIN|LIMIT|FLOOR|THRESH|BUDGET|CAP|BOUND|TOL|WINDOW|SLACK`. It returns 33
rows, 29 distinct names and 13 files. That is a floor and it is impure. Seven rows are
accumulators or flags initialised to 0 (`CEILING_LIVE`, `CEILING_COUNT`, `CITE_UNBOUNDED`,
`RESOLVED_TERMINAL`, `TERMINAL`, `UNBOUNDED`, `GA_UNBOUNDED_CITES`), not limits. The name grammar
cannot express a table, so `validate-artifact-budget.sh`'s six `name|bytes|remedy` rows (for
example `pipeline-snapshot.md|6000|trim`) were added by hand. The 85 literal `-gt/-ge/-lt/-le N`
comparisons with non-zero N, across 29 files, were counted but not joined. Control:
`MAJOR_EXIT_CEILING=3` is present (1). An impossible name returns 0.

**(2) The layer side.** A threshold-phrase grep (`≥ ≤ >= <=`, `at least/most N`, `N+`, `N%`,
`nonzero`, `ceiling|threshold|budget`, and similar) over the 49 bodies returns 95 lines in 21
files. The known line is present (Rule-8's "nonzero MAJOR", count 1). Only one layer body names
a validator constant by its identifier: `TERMINAL`, which is an English word in a retro step
heading and so a false positive. Basename references to `core/scripts/*.sh` give 43 (file, script)
pairs over 19 files and 18 scripts. These are citations, not restatements of a value.

**(3) The join, keyed on the numeric value.** Joining the integers on threshold-phrase lines
against the validator value set gives 63 (line, value) hits on 51 lines. Grouped by (value,
subject), only TWO are true restatements of an enforced value, and BOTH AGREE. The first is
`extensions/steps-domain/retro-domain-close-out-sweep.md` citing `pipeline-snapshot.md|6000|trim`
(6000 = 6000). The second is Rule-8's "2+ passes" against `STALL_THRESHOLD=2` (2 = 2). **The
override's only number agrees with the validator. Its staleness lives in "nonzero MAJOR" against
`blocking > MAJOR_EXIT_CEILING`, which carries no digit in the override, so a numeric detector
scores the case this entry was filed on as CLEAN.** The FP set, by value:
- **10.** The adversary's ten-findings floor (`bug-investigation-push.md`) lives only in
  `adversary.md` prose. A grep for its enforcement returned 7 hits, all 7 `findings_minor` or
  unrelated loop bounds, so the real count is 0. The other 10s (`DENSITY_MIN=10` in the stub audit,
  `N≥10` harness reps, `≤~10-line` edits, `≤$10`) are unrelated subjects.
- **3 and 2.** These are Rule 8's intensity story-count thresholds (`≥3`, `≤2`, "exceeds 2").
  Enforcement in `core/scripts`+`core/hooks` is 0 (`carry-over-single` appears 0 times there and
  13 times in `SKILL.md`+`steps/`), so these are prose rules with no validator.
- **8.** A deploy cluster count, not `PART_CAP=8`.
- **50.** A wire-byte reduction percentage and a proposal rate, not `MAX_SHARE_PCT=50`.
- **6.** A section number, not `MAX_BEATS=6`.
- **0, 1, 2 and 3 everywhere else.** These are ordinary prose (`≥1 test file`, `N≥2 fixture`,
  exit codes).
Small integers collide with everything, and that is the structural reason this key cannot work.
**Verdict on the numeric key: constructible, with an FP set of 49 of 51 lines, and blind to its own
motivating subject. Do not build it.**

**A key that DOES reach the motivating instance: core files the override BODY cites, diffed
`base_sha..theirs`.** No arm does this today. Line 1838 diffs only the SHADOWED file, and
`OVERRIDE-DELEGATES-INTO-SHADOW` asks about reachability, not drift. `retired-layer-passage.sh`
matches core lines DELETED base..theirs, and the stale sentence is still live in core, so it
cannot fire. Measured with HEAD standing in for the pull's `theirs` (a real run would use the
pull's ref): over the 9 overrides, backticked `*.md|*.sh|*.yaml` tokens that resolve to a core
file give 7 citations in 3 overrides, and 6 of them changed since their `base_sha`. **3 of 9
overrides would fire.** One is the known true positive: Rule-8 cites `team-roles/adversary.md`,
which `39f0cb0b` edited. The other two (`check-5` citing `implementation.md`, and `domain-sections`
citing `gate-validation.md`, `route.md` and `validate-artifact-budget.sh`) are unadjudicated:
"changed since base" is a drift signal, not a staleness verdict. **The key reached Rule-8 only
because `39f0cb0b` happened to co-edit `adversary.md`. A validator-only migration would have been
invisible to it too, so it narrows the blind set without closing it.** Size, if scheduled: one
report-only arm in `layer-drift.sh` (OVERRIDE-CITED-CORE-DRIFT, never blocking), reusing the
existing `git diff --quiet base_sha THEIRS -- <path>` shape, plus a fixture seeding one cited file
changed and one unchanged. Its FP set must be adjudicated on the two non-Rule-8 hits before it
ships. **The direct fix for the measured defect is cheaper and lies on the distribution side:
reword the four core prose sites to the arm-E predicate. The consumer then inherits it through the
existing `HARD-OVERRIDE-DRIFT-SECTION` on its next pull, because the shadowed section will finally
move.**

**Batch 185: the motivating case was core-prose staleness, and that half is fixed.** The stale
STALL predicate ("a nonzero MAJOR held at zero CRITICAL") was reworded at every core site to the
validator's arm-E predicate, citing `MAJOR_EXIT_CEILING`, `CRITICAL_EXIT_CEILING` and
`STALL_THRESHOLD` by name and carrying no digit: `core/skills/ai-dlc/SKILL.md`, both hooks'
comments and deny messages, the validator's own arm-E comment, and `divergence-hard-block`. Both
hooks also gained an explicit `CEILING)` branch, because their catch-all had described the
validator's fourth rc-3 state as a stall. The detector question is unchanged and stays open as
the census above leaves it: no layer-drift arm sees an override restating a threshold that moved
into a validator.

verify: manual -- this entry records a gap, not a receipt. Do not close it on a green
`layer-drift.sh` run; that green is the defect.

## BL-132 — the safe-stop acquittal answers a question about BEHAVIOUR with a test on ancestry

**Operator decision, 2026-10-01: left open and unscheduled.** The reference consumer archived
`PC-S340` as `CLOSED AS REJECTED — BY DESIGN, adjudicated 2026-09-29` in
`_bmad-output/ai-dlc-update/push-candidate-ledger.archive.md`, so it is no longer a live candidate
and this entry does not outrank distribution-internal work on its provenance.

Carries the reference consumer's `PC-S340-SAFE-STOP-ACQUITTAL-TESTS-ANCESTRY-NOT-CONTENT`, so it is
PC-backed and ranks above any distribution-internal entry under the provenance-first rule. **The
candidate's DEFECT is real and its stated REMEDY is refuted — both halves were measured, and the
adjudication has been carried back in `docs/reviews/graph-s340-adjudication-brief.md` §1b.**

`self-update-gate.sh`'s `advise_safe_stop` acquits a split with "SPLIT BUYS NOTHING HERE", gated on
`machinery_at_or_past()` (`:205-213`), which is `git merge-base --is-ancestor` on the stamp's
`skill_commit` and nothing else. The sentence it emits is a claim about what the CLASSIFIER will
do; the test underneath it is about where a sha sits in the graph.

**DO NOT BUILD THE CONTENT/BYTE-EQUALITY ARM. It was scored and it does not fire on the pull that
filed the candidate.** The filing state was reconstructed from the consumer's own stamp history and
the shipping gate driven against it, giving a real candidate of 0.454.0. A byte arm stays quiet at
every candidate in the range, and the filing-state consumer matched **0 of 3** paths a hop would
write. Currency by set: machinery set (123) NO — 3 differ, 1 absent; `reconcile/` subtree (27) NO —
`setup-sites.md` differs; `reconcile/` executables (23) YES, 23 of 23. Control: the same scorer with
the candidate set to BASE returns 120 match / 0 differ, so it discriminates. `setup-sites.md` is a
genuine classifier input — `preclassify.sh` reads it at `:117`, `:218` and `:329` — and it genuinely
changed, so byte equality is FALSE at every scope above the executable subset.

**The claim measures TRUE behaviourally, which is what makes this a defect rather than a bad
filing.** The consumer's installed engine and the engine at 0.454.0, run against one tree with one
set of arguments: **0 changed classifier rows over 59 paths, against a control of 4** changed rows
versus a 0.432.0 engine, with `diff -rq` confirming the two engine directories differ. The hop's
engine change was inert and the gate could not say so.

**THE BEHAVIOURAL DIFFERENTIAL IS REFUTED AS THE REMEDY, MEASURED AT BATCH 137 BY A CONTRACT
ADVERSARY AND RE-DERIVED BY THE LEAD. DO NOT BUILD IT.** It was the predicate this entry named,
and it fails for the same reason as the byte arm it was meant to replace, only harder:

- **The filed INSTANCE is not an instance.** Reconstructed filing state (consumer at
  `8e53e4b41^`, stamp `0.452.0` / `11bdeb8e`; control: `HEAD` stamp reads `0.608.0` / `03c04e74`,
  so the extraction is genuinely historical), driving the consumer's own installed engine with
  `11bdeb8e cb3ac04d`: `SPLIT BUYS NOTHING HERE` rows = **0**. The run takes the `else` branch.
  `machinery_at_or_past` is FALSE there (`--is-ancestor b634e42d 11bdeb8e` rc=1; control:
  `--is-ancestor b634e42d cb3ac04d` rc=0) because the stamp is BEHIND the candidate. The
  acquittal never fired on the pull this entry was filed from, so a new conjunct ANDed under
  that guard changes nothing on the motivating case, in either direction.
- **The central measurement had a subject side byte-identical to its own baseline.**
  `preclassify.sh` is blob `860ed5494c38` at 0.452.0, 0.454.0 AND 0.456.0 (control:
  `setup-sites.md` differs across the same pair, `ba22836977` vs `88a0b4a50e`). The "0 changed
  classifier rows against a control of 4" was two runs of the SAME program; `diff -rq` proved the
  DIRECTORIES differ and never that the CLASSIFIER did.
- **The 59-row population is not the one the gate runs on.** On the real range the classifier
  emits **10** rows, all `UPSTREAM-ONLY` (6) or `UPSTREAM-ONLY-ADD` (4) — no consumer delta, so
  no judgement for two engines to disagree about. 59 came from a synthetic `0.432.0..0.456.0`.
- **The false-positive set is 92%.** Over the last 40 release hops `preclassify.sh` is UNCHANGED
  on **37** (control: the same walk over all of `core/` shows 34 of 40 hops changed, so the walk
  discriminates). The arm this entry banned the byte predicate for was vacuous on 7 of 39; this
  one is vacuous on 37 of 40.
- **No control-engine rule is derivable, and that half is a PROOF and not a bug.** Control = the
  engine at BASE is byte-identical to the installed engine exactly when it is needed. Control =
  N releases back is a magic number: the first differing `preclassify.sh` sits **7** releases
  back from the candidate, and N moves with cadence. A resolution control needs a KNOWN-DIFFERENT
  engine, establishable only by the byte comparison this entry bans or by an unbounded walk.

**THE DEFECT IS STILL REAL AND THE ENTRY STAYS LIVE.** Nothing above contradicts the finding that
the emitted sentence is a claim about BEHAVIOUR while the test underneath is graph-topological.
What is refuted is that a behavioural differential can carry it.

**THE DIRECTION THAT SURVIVES EVERY MEASUREMENT IS NARROWER: REFUSE, DO NOT ACQUIT.** Withhold the
acquittal when the classifier is byte-identical across `installed -> candidate`, because then the
ancestry test is the ONLY evidence and the sentence it licenses — "its machinery has already
landed" — is unsupported. One `git rev-parse` pair, no control engine, and it fires on the 37 of
40 hops where the differential is silent. It is NOT the banned byte-equality arm: that one gated
the PULL's content, this gates the ACQUITTAL's own evidence. It weakens an acquittal rather than
strengthening one, which is the asymmetry `self-update-gate.sh` already states for itself —
refusing costs less than firing wrongly. **Scope is the operator's; this is recorded as the
measured direction, not taken.**

**THREE THINGS ARE UNMEASURED AND THEY ARE WHY THIS IS FILED RATHER THAN BUILT.** Shipping a check
whose false-positive set has not been run is forbidden here, and this one has three open questions:

- **The new predicate's own FP set has not been run.** It needs its own battery.
- **A 10-ROW POPULATION CANNOT RESOLVE THIS DIFFERENTIAL.** Measured: at the filing range the
  subject read `0` and **the control also read `0`** — two demonstrably different engines producing
  identical output. That null was worthless and was nearly shipped as a result. Only at 59 rows did
  the control fire. **An arm of this shape must assert its own resolution in the same run or report
  UNDECIDED**, which is already this gate's doctrine for an unattributable answer.
- **COST IS NOT THE BLOCKER, AND AN EARLIER REVISION OF THIS ENTRY SAID IT MIGHT BE.** That
  revision put the resolution control at "a third, deliberately-older engine extracted per candidate
  ref" with a cost "not yet a number". **"Per candidate" was the load-bearing half and it is
  wrong**: `advise_safe_stop()` returns early on `AI_DLC_GATE_IN_SAFE_STOP`,
  which `:125` exports before the `--safe-stop` walk begins, so every per-candidate recursion
  short-circuits before reaching the acquittal and the differential is evaluated exactly once, on
  the single candidate the walk elected. Measured at **≈7s per invocation, independent of range
  length** — two subtree extractions at 0.03s each plus three `preclassify.sh` runs at ~2.3s over a
  59-row population, three interleaved reps. What blocks this is the unmeasured FP set above and the
  absence of a rule for CHOOSING the control engine, not the price.

**A byte predicate would also be VACUOUSLY TRUE on a large minority of hops**, which is a second
reason the refuted remedy must not come back: **7 of 39 consecutive release hops change ZERO
machinery paths** (0.427→0.428, 0.433→0.434, 0.437→0.438, 0.445→0.446, 0.453→0.454, 0.458→0.459,
0.464→0.465), against a control of **0 of 39** having an empty full diff.

**ONE CONJUNCT OF THE EVENTUAL ARM ALREADY SHIPPED, IN `v0.466.0`, AND MUST NOT BE REBUILT HERE.**
The acquittal now refuses on a tree carrying `.claude/.ai-dlc-applying`. That was filed as part of
this entry and then found to have a subject TODAY under the current ancestry route — a withheld
apply leaves `skill_commit` advanced beside a `commit` at base, and the acquittal fired on that
partial tree. It survives the switch to a behavioural predicate, because a partial tree can classify
identically and still not be a tree to acquit. **This entry is now only about the ancestry-vs-
behaviour predicate**, and closing it requires that, not the marker guard.

**Tiered DEFECT.** It wrongly advises a split on a consumer whose engine is already behaviourally
current. It is bounded: `advise_safe_stop` is called at exactly two sites, each immediately after
an `emit SELF-UPDATE-DEFER` inside a deferral block, so the acquittal is unreachable except behind
a DEFER and a wrong answer can only mis-advise a consumer already deferring — never one on the
happy path. **The bound re-derives TRUE; the line numbers this entry used to cite did not.** Every
anchor here had moved by `5540c7c6` — the acquittal, `machinery_at_or_past`, both call sites and
the early return — so the citations are given by NAME above and the reader greps for them. An
entry citing `path:line` into a file that moves is `BL-133`'s own subject, occurring here.

**THERE ARE TWO `SPLIT BUYS NOTHING HERE` EMITTERS AND ONLY ONE IS THE SUBJECT.** The second is
the push-refusal case with candidate `"-"`, whose window carries **0** non-comment references to
`machinery_at_or_past` or `advise_safe_stop` (control: 4 `emit` calls in the same window, so the
grep works) — its only textual hit is a comment explaining why the walk is deliberately skipped
there. Same banner, different premise, no ancestry test. **Name the subject by its
`machinery_at_or_past` guard, never by the banner text**, and note that the fixture asserts
`grep -c 'SPLIT BUYS NOTHING'` against expected counts at six sites: a fix landing on the wrong
emitter moves those counts and satisfies a banner-counting receipt while changing nothing.

**THE FIXTURE'S OWN MUTATION ANCHOR IS AIMED AT THE LINE A FIX MUST RESHAPE.**
`core/fixtures/self-update-gate/run.sh`'s `SC_A3` anchors on the literal
`    if machinery_at_or_past "$_ss"; then`, which matches the shipping gate exactly **1** time
(control: a bogus anchor matches 0). Any fix that rewrites that line empties the mutant silently —
it applies to nothing, the file stays byte-identical, and the battery reads SURVIVED. Assert
`! cmp -s` before scoring, and re-anchor the mutant on the predicate that DECIDES.

**THE RECEIPT IS REFUTED: IT REJECTS THE CORRECT FIX AND CLOSES ON THE DESTRUCTIVE INVERSE.**
Six candidates built from the shipping file, each asserted applied by `cmp -s` first. A real
differential — extract the candidate engine, run both `preclassify.sh`, compare — scores **1**,
REJECTED, because the receipt demands `show|archive|worktree` and `preclassify` on ONE line with
no `|` between them, and the extraction is necessarily two lines: `preclassify.sh` sources
`lib.sh` at `:47` and reads `setup-sites.md` via `dirname "$0"`, so it cannot be extracted as a
single file. Meanwhile the same line inside an UNCALLED function, the same line under `if false`,
an unconditional `: "$(git show … | head -0)"` consulting nothing, AND a mutant replacing the
guard with `git archive … || true` — which acquits **every** consumer unconditionally — all score
**0**, closed. The inverse mutant emits 1 `SPLIT BUYS NOTHING` row on the motivating case against
the shipping tree's 0, so the FIXTURE separates them and the receipt does not. **Key the
replacement on the EMISSION SITE** — that the acquittal's own guard consults a behaviour term —
plus a non-vacuity arm, and score it against all six before filing it.

**Receipt replaced: it now drives the acquittal's EMISSION, not the text of its guard.** It builds a mini-distribution in which r1 changes `preclassify.sh` and r2 defers, then runs the shipping gate three times against one consumer: stamp at r1 with the r1 engine installed (`current`), stamp at r1 with the base engine still installed (`stale`), and stamp at base (`behind`). It exits 0 only when `stale` withholds `SPLIT BUYS NOTHING HERE` on the SAFE-STOP row naming r1, `current` still prints it and `behind` withholds it. It reads that row by its ref and never by its banner, so the `-` emitter cannot satisfy it. It exits 9 when the walk stops naming r1, when a run emits CARRY or UNDECIDED, or when there is not exactly one row naming r1. Scored under `set -uo pipefail` in copies of `core/`, with every edit asserted applied: tree as-is 1 (`stale=acquit`); the fix as a content check inside `machinery_at_or_past` 0; the fix as a separate `installed_matches` helper at the emission site 0; `git archive … || true` 1; `if false` 1; the helper defined but uncalled 1; `head -0` 1; the content check inverted 1; the content check comparing the candidate against itself 1; engine absent 9. The narrower direction recorded above (withhold when `preclassify.sh` is byte-identical across the hop) reads 1, because the classifier changes in this world. A behavioural-differential remedy was not scored: the mini-distribution's `preclassify.sh` is a stub, not a classifier, so a differential has nothing to compare here. **This receipt contradicts the body.** Both fixes that close it compare the consumer's installed bytes against the candidate, which is the content arm this entry says not to build, and on a hop that changes no machinery path their loop is empty and they acquit. A CLOSE-CANDIDATE from this receipt is therefore a prompt to settle that contradiction, not a close.

verify: sh G="$PWD/core/skills/ai-dlc-update/reconcile/self-update-gate.sh"; [ -f "$G" ] || exit 9; w="$(mktemp -d)" || exit 9; P=skills/ai-dlc-update/reconcile/preclassify.sh; S=skills/ai-dlc/steps/gate-validation.md; g() { git -C "$w/d" -c user.name=r -c user.email=r@r -c commit.gpgsign=false "$@"; }; v() { printf '# gate\n'; for a in "$@"; do printf '<!-- CHECK_LOADED: %s -->\n' "$a"; done; }; mkdir -p "$w/d/core/skills/ai-dlc-update/reconcile" "$w/d/core/skills/ai-dlc/steps" "$w/c/.claude/skills/ai-dlc-update/reconcile" "$w/c/.claude/skills/ai-dlc/steps" "$w/c/.githooks" || exit 9; git init -q "$w/d" || exit 9; echo 1.0.0 > "$w/d/VERSION"; v 1 2 > "$w/d/core/$S"; echo "engine v0" > "$w/d/core/$P"; g add -A && g commit -qm base || exit 9; B="$(g rev-parse HEAD)"; echo 1.1.0 > "$w/d/VERSION"; echo "engine v1" > "$w/d/core/$P"; g add -A && g commit -qm r1 || exit 9; R="$(g rev-parse HEAD)"; echo 1.2.0 > "$w/d/VERSION"; v 1 2 3 > "$w/d/core/$S"; g add -A && g commit -qm r2 || exit 9; T="$(g rev-parse HEAD)"; v 1 2 > "$w/c/.claude/$S"; printf '#!/usr/bin/env bash\nexit 0\n' > "$w/c/.githooks/pre-push" || exit 9; k() { printf 'version: 1.0.0\ncommit: %s\nskill_version: 1.1.0\nskill_commit: %s\n' "$B" "$1" > "$w/c/.claude/.ai-dlc-version"; echo "engine $2" > "$w/c/.claude/$P"; [ "$(bash "$G" --safe-stop "$w/d" "$B" "$T" "$w/c" 2>/dev/null)" = "$R" ] || { echo walk; return; }; bash "$G" "$w/d" "$B" "$T" "$w/c" 2>/dev/null | awk -F'\t' -v r="$R" '$1 ~ /^SELF-UPDATE-(CARRY|UNDECIDED)$/ {u++} $1=="SELF-UPDATE-SAFE-STOP" && $2==r {n++; if (index($3, "SPLIT BUYS NOTHING HERE")) a++} END {print (u ? "undecided" : (n == 1 ? (a ? "acquit" : "withheld") : "none"))}'; }; st="$(k "$R" v0)"; cu="$(k "$R" v1)"; bh="$(k "$B" v0)"; for x in "$st" "$cu" "$bh"; do case "$x" in acquit|withheld) ;; *) echo "BL132-PRECONDITION stale=$st current=$cu behind=$bh" >&2; exit 9 ;; esac; done; [ "$st" = withheld ] && [ "$cu" = acquit ] && [ "$bh" = withheld ] && exit 0; echo "BL132-ACQUITTAL-ON-ANCESTRY stale=$st current=$cu behind=$bh" >&2; exit 1

## BL-145 — a docs commit that MENTIONS a candidate id is reported to the consumer as upstream having absorbed it

**Found while scoping batch 43**, 2026-09-02, and NOT fixed here — the fix is a change to
`named_absorbed()`'s join, which is a bootstrapping step the consumer runs to classify its own
pull, and this batch is already changing three hooks in the same range. Distribution-internal in
its cause and CONSUMER-FACING in its effect, so it ranks below any PC-backed entry a sweep turns
up but above the distribution-only entries.

`named_absorbed()` (`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:402`) resolves
"did upstream take this candidate" with `git log -F --grep`, which reads **commit MESSAGES**. A
message is text about a program, not the program: any commit whose message contains the id
satisfies the join, including a commit that changes no code at all.

**THIS PROGRAM MANUFACTURES ITS OWN FALSE POSITIVES.** The plan's resume block names candidate
ids in prose, and every edit to it is a `docs(plan):` commit carrying those ids in its message.
Measured against `origin/main` at `v0.480.0`, driving the shipping script over the reference
consumer's live ledger: **6 entries report `NAMED-UPSTREAM` where EVERY commit naming them
touches zero `core/` paths.**

    PC-S295-RETRO-PARALLEL-OPEN-COUNT-METHOD                             1 commit, 0 core
    PC-S312-TRUNK-PUSH-DECLINES-TO-POLICE-THE-TRUNK                      1 commit, 0 core
    PC-S334-ROTATE-ACCEPTANCE-TEST-FALSE-FAILS-ON-THE-WORKFLOW-IT-DOCUMENTS  1 commit, 0 core
    PC-S336-STEP-1-AUTOPUSH-IS-THE-UNGUARDED-TWIN-OF-THE-PUSH-STEP-2-HARDENED 1 commit, 0 core
    PC-S305-BARE-BOLD-ENTRY-IS-INVISIBLE-TO-EVERY-REVERIFY                1 commit, 0 core
    PC-S340-SAFE-STOP-ACQUITTAL-TESTS-ANCESTRY-NOT-CONTENT                1 commit, 0 core

`PC-S295-RETRO-PARALLEL-OPEN-COUNT-METHOD`'s sole naming commit is `aa819280`,
*"docs(plan): batch 32 merged, so the block that told you to run it is now a description of
finished work"* — **one file changed, zero core paths**. Control in the same derivation:
`PC-S340-VALIDATE-SPAWN-LEDGER-OVERSHOOTS-CHECK-22-DECLARED-ROLE-SCOPE` resolves two commits
touching four `core/` files each, so the discriminator separates the two classes rather than
scoring everything docs-only.

**IT IS NOT A COSMETIC ROW.** `NAMED-UPSTREAM` is the signal a pull session reads to decide a
candidate was taken, and the standing instruction in `## Start here` is to put every closed id in
the RELEASE COMMIT MESSAGE precisely because this join reads messages. That instruction is
correct and it is also what makes the false-positive class reachable: the same channel carries
both a fix's citation and a plan's cross-reference, and the join cannot tell them apart.
`ledger-reverify.sh:978` already records one instance of this exact class from v0.153.0 — *"the
entry was then wrongly recorded upstream as absorbed on that basis — a citation read as a fix"* —
so the shape is known; what is new is that this program is now the largest producer of it.

**THE OBVIOUS FIX IS NOT OBVIOUSLY RIGHT, WHICH IS WHY THIS IS FILED RATHER THAN TAKEN.**
Requiring a naming commit to touch `core/` would drop all six, and it would also drop a genuine
close whose remedy was a `steps/*.md` or `templates/` change — both reach a consumer and neither
lives under `core/` in every case. Deriving "did this commit change anything the consumer
installs" is the real predicate, and its false-positive set has not been measured. Scope that
before building it.

**A THIRD CLASS, MEASURED AT BATCH 113, AND IT DEFEATS THE CANDIDATE FIX ABOVE.** The six rows
of the table are docs-only commits, and the `touches core/` predicate drops all six. It does NOT
drop this one. `b3debba3` (`v0.568.0`) names
`PC-S308-GATE-METRICS-CHECK2-STALE-VERDICT-READ-ORDER` in its message with the true sentence
*"discharged by an archived entry and cited by no release commit until now"*, and it touches
**6** `core/` paths — `core/scripts/derive-fixture-readsets.sh`,
`core/skills/ai-dlc/steps/gate-validation.md` and four others. Control in the same invocation:
`aa819280`, the table's own docs-only example, touches **0**; an impossible path prefix returns 0
from the same commit. So the naming commit passes every reachability filter proposed here while
the candidate's subject, `validate-suppression-lifetime.sh`, appears **0** times in its diffstat
against a control of **1** for `gate-validation.md`.

**The citation was TRUE and the close was still WRONG.** The archived entry it refers to,
`BL-194`, says in its own provenance paragraph *"This is NOT that candidate's subject"* and names
`BL-195` as the filed subject's disposition. `BL-195` is live and its premise re-derives in full.
The consumer's sweep read the naming commits for explicit discharge language, found some, and
closed the candidate 14 days later as `ADOPTED UPSTREAM (v0.568.0)`.

**This program predicted it and then did it anyway.** `docs/plans/graph-ledger-full-drain.md`
records the citation being DELIBERATELY WITHHELD at batch 71 for exactly this reason — *"a
citation would make `named_absorbed()` emit a `NAMED-UPSTREAM` row telling the consumer to close
an entry this release did not resolve"* — after which the resulting `discharged-but-INVISIBLE 1`
row was carried as a bookkeeping irritant for ~28 batches until batch 102 cleared it by adding
the citation. **Clearing that row is what caused the false close**, so the two obligations are in
direct conflict and only one of them is mechanised.

**What this means for the fix.** The real predicate is not "did the commit change something the
consumer installs" but "does the commit change something THIS id's subject depends on". The
engine now takes a per-id subject path from the entry's own receipt paths (see the batch-185
paragraph below), and that datum does not separate `b3debba3`, which touches its receipt file. A weaker but constructible half: a release commit citing an id it does not FIX needs a
distinguishable form, so the join can exclude it — which is a producer-side change, where there
is one writer, rather than a reader-side heuristic over every historical message.

**Sibling to `BL-089`** — a status that cannot distinguish "I measured nothing" from a genuine
reproduction. Same class, and this is the absorption side of it.

**Stated limitation of the receipt below.** It anchors on one real id whose naming commit is
docs-only today. A future core-touching commit naming that id closes the receipt without the join
being fixed; if that happens, re-anchor on another row of the table above rather than reading the
close. It is scored three ways against THIS corpus's convention, where exit 0 is the fix being
present — the subject id exits 1 (still live), an id backed by a core-touching fix exits 0, and
an impossible id exits 9 rather than reporting a false close. The first cut of this receipt was
written the other way round, carrying `ledger-reverify.sh`'s opposite convention into a
`docs/backlog.md` entry, and it read as an incidental close in the histogram.

**Held note (batch 178): NARROWED, STAYS OPEN.** On `b178-b2`, a naming set in which no commit
changes a path under `core/` or `templates/` (the two trees `install.sh` copies into a consumer) is
emitted as `NAMED-UPSTREAM-DOCS-ONLY`. The row is kept, with the full sha list. `named_reach` lists
files with `git log --no-walk --stdin -m`, because a merge lists none without `-m`. If the listing
fails, the answer is the old kind, never docs-only. The same predicate is folded into the
`NAMED-UPSTREAM-AMBIGUOUS` detail. The new kind is documented in SKILL.md step 3f and step 8 and in
emit-report's heading, which satisfies I39, and `docs/vocabulary-index.md` was re-rendered. On the
reference consumer's archive with its close annotations stripped (the population where upstream
named entries), 33 of 214 NAMED-UPSTREAM rows move to DOCS-ONLY. Re-derived with `git diff-tree -m`,
none of the 33 has a naming commit that touches `core/` or `templates/`. The control: the first 8
rows that stayed each have one. The live ledger moves 0 rows, because it has no open entry upstream
names. **What survives is the third class.** A commit that changes `core/` but not the entry's
subject (`b3debba3` for PC-S308) still reads NAMED-UPSTREAM. Batch 185 closes the part of it that
touches no receipt file. `b3debba3` touches PC-S308's receipt file and leaves only the receipt
substring unchanged, and substring matching is refuted (see below), so PC-S308 still reads
NAMED-UPSTREAM.

**Amended on `b178-b2-rel`: a naming commit that changes `VERSION` also reaches.** In this repo's
release convention the release commit names the id and changes only `CHANGELOG.md` and `VERSION`,
while its parent carries the `core/` fix and names nothing, so the first cut read real absorptions
as DOCS-ONLY. Its row text and SKILL.md step 8 also forbade annotating them. Both texts now say
the naming is not evidence and send the operator to the entry's subject. Re-run on the same
stripped archive (base `f7eec6f5`, theirs = the branch tip), DOCS-ONLY falls from 32 to 5 and
NAMED-UPSTREAM rises from 201 to 228. Every one of the 27 movers has a VERSION-touching naming
commit and no `core/` or `templates/` one, re-derived per parent with `git diff-tree`. Each of the 5
survivors has only naming commits that touch none of the three. Rows of every other kind are
byte-identical between the two engines. A release that names an id only to adjudicate it, such as
`c79a1d55` (ALREADY-FIXED), now reads NAMED-UPSTREAM too. That kind already says naming is not
absorbing. Fixture arm S954 holds the release shape, and its mutant `reach-no-version` is killed by
that cell alone. The receipt below has no VERSION-touching commit, so its verdict does not move.

The replacement receipt drives `ledger-reverify.sh` over three single-commit entries: docs-only,
templates-only, and a core commit that mentions an id whose subject it never touches. It exits 1
while that third class reads NAMED-UPSTREAM, which today is by design, so the entry stays open. It
exits 1 too if the docs-only entry is not emitted as DOCS-ONLY or the templates-only entry is
demoted. Scored: B1+B5 tip 1 (docs read as NAMED-UPSTREAM), fix 1 (third class only), a
`core/`-only predicate 1, and the delete-the-row fix 1 (`docs=<no row>`). Fixture arms: S950
docs-only, S951 templates-only, S952 merge, S953 ambiguous reach, each with a mutant (`reach-off`,
`reach-core-only`, `reach-no-m`).

**Producer half, batch 183: the third class is closed for a citation the WRITER marks. The
per-id-subject half stays open.** A distribution release that cites an id it did not discharge
now names it on its own body line, `Not-discharged: PC-S<n>` or `Not-discharged: PC-S<n>-<SLUG>`.
`named_cited_filter` in `ledger-reverify.sh` drops a commit from the naming set when only that
line names the id. It runs at all four query sites, before the count and before `named_reach`.
A set with no commits left emits `NAMED-UPSTREAM-CITED-ONLY` with every sha. Arm F of
`scripts/validate-release-version.sh` refuses a misspelled or misplaced form in a release range;
its false-positive set over 2001 `origin/main` messages is 0. This closes only the case where the
writer knows the citation is not a discharge. It is forward-only, so `b3debba3` still reads
NAMED-UPSTREAM. A consumer's installed engine reads the form as an ordinary mention until it
pulls. A core-touching commit that BELIEVES it discharged an id, and touched none of that id's
subject, read NAMED-UPSTREAM here. Batch 185 demotes it when the commit touches none of the entry's
receipt files. It still reads NAMED-UPSTREAM when the commit touches a receipt file without changing
the receipt substring, which is the PC-S308 shape. The
receipt below drives the fixed engine over four shapes: form-only, both forms, inline form, and
form-on-core plus an ordinary docs mention. It also uses a never-named control. Scored under
`set -uo pipefail`: tip (`abe3afb7`) 1, fix 0, mutants `filter-off`, `filter-any-form-line`,
`filter-unanchored`, `reach-unfiltered` and `cited-only-no-row` 1 each, engine absent 9. Fixture
arms S955-S959 sit in the `cited_only` unit of `ledger-reverify`, shard d, with the same five
mutants. The citation must appear in the BODY of the squash or release commit that lands on
`main`, which is the message a consumer's engine reads, and a misspelling there is caught by running
`scripts/validate-release-version.sh --commit <squash sha>` after the merge.

**Receipt replaced: the producer half shipped and the previous receipt exits 0, so it now tests the open half, claim 3.** It drives the shipping `ledger-reverify.sh` over four entries whose receipt subject is `core/subject.sh`: a core commit naming an id and changing only `core/other.sh` (the third class), a commit naming an id and changing the subject together with another core file (genuine), a docs-only naming, and a never-named control. It exits 0 only when the third class still has a `NAMED-` row whose kind is none of NAMED-UPSTREAM, -DOCS-ONLY, -CITED-ONLY or -AMBIGUOUS, while the genuine naming still reads NAMED-UPSTREAM and the docs naming still reads NAMED-UPSTREAM-DOCS-ONLY. Relabelling the third class as DOCS-ONLY does not satisfy it, because that row's text says no naming commit changes `core/`, which would be false here. The receipt also assumes the subject is taken from the entry's receipt path, which is the only per-id datum the seed carries. A fix that reads another datum has to re-anchor this receipt. It exits 9 when the engine is absent or the never-named control gains a `NAMED-` row. Scored under `set -uo pipefail` in copies of `core/`, with every edit asserted applied: tree as-is 1 (`third=NAMED-UPSTREAM`); a fix in the main loop that reads the receipt path and emits a new kind 0; a fix with a `named_touches` helper and a differently named kind 0; demote every core naming on a receipt-bearing entry 1; drop the row 1; relabel it DOCS-ONLY 1; the subject test inverted 1; a test for the subject existing at theirs instead of being touched 1; engine absent 9.

**Batch 185: a naming set that reaches code and touches NO receipt file is closed, and the PC-S308 shape stays open.** `named_subject` in `ledger-reverify.sh` takes the entry's subject set from the union of its `theirs_has|theirs_lacks` receipt paths, staged once before the entry loop. A path absent at theirs is resolved by unique basename at theirs, the way the verb dispatch already resolves a consumer-layout path. A path that matches 0 or more than 1 file, or that git could not read, is unresolvable, and any unresolvable path keeps the whole entry at the old kind. A naming commit that changes `VERSION` is judged over its release span: from the previous commit that changed `VERSION` (exclusive) through the naming commit. A naming commit that is not a release is judged on its own listing. Any listing failure answers the old kind. When the reach is `code`, the subject set is non-empty and resolved, and no naming commit changes any subject path, the row is `NAMED-UPSTREAM-OFF-SUBJECT`. That kind is decided after `cited` and `docs`, keeps every sha, and is never a close. An entry with no path receipt keeps its prior kind byte-for-byte. The ambiguous row does not take the predicate, because it stands for two or more entries with different receipt paths. **What stays open is the real PC-S308 shape.** `b3debba3` touches PC-S308's receipt file `core/skills/ai-dlc/steps/gate-validation.md` (1 in its `diff-tree -m` listing, against 0 for `validate-suppression-lifetime.sh`). None of the 32 changed lines in that file carries the receipt substring `gate-metrics.jsonl`, which occurs 4 times in the file at HEAD. A per-file test therefore scores it `touched`, and it still reads NAMED-UPSTREAM. **Substring matching is refuted, so do not build it.** The contract adversary modelled "did a naming commit change the receipt substring" in Python over the reference consumer's archive. It demoted 16 of 50 on-subject rows that were genuine absorptions whose anchors had gone stale. That figure comes from the model and not from a shipped engine. A fix for the remainder needs a datum that separates a cross-reference from a fix on the same file.

**Receipt replaced again: the previous one exits 0 on the per-file fix (scored on the R1 tip under `set -uo pipefail`) while PC-S308 is still open, which would retire a live entry.** The new receipt drives the shipping `ledger-reverify.sh` over seven entries in one repo. Clause (i) is a core commit that touches the entry's receipt file and leaves the receipt substring unchanged. The receipt exits 0 only when that entry has a `NAMED-` row outside NAMED-UPSTREAM, -DOCS-ONLY, -CITED-ONLY and -AMBIGUOUS, so it exits 1 while the PC-S308 shape stays open. Five controls each exit 1 and name their own clause on stderr when they fail. (ii) A core commit touching no receipt file must read NAMED-UPSTREAM-OFF-SUBJECT. (iii) A squash-shaped release, on an entry with two receipt paths where only the second is touched, must read NAMED-UPSTREAM. (iv) A branch-shaped release must read NAMED-UPSTREAM; its fix parent names nothing, and the naming child changes only `CHANGELOG.md` and `VERSION`. (v) A non-release naming commit must read OFF-SUBJECT; an unnamed neighbour in the same span touched its subject. (vi) A docs-only naming must read DOCS-ONLY. (vii) A never-named control that gains a `NAMED-` row exits 9, and so does an absent engine. The controls run before clause (i), so a broken engine never reports as the open entry. Scored under `set -uo pipefail` from the repo root, in scratch copies of `core/` with every mutation asserted applied: R1 tip 1 (`i-RECEIPT-FILE-TOUCHED-SUBSTRING-UNCHANGED-READ-AS-ABSORBED filetouched=NAMED-UPSTREAM`); base `c18897d9` 1 (`CONTROL-ii`); `span-off` 1 (`CONTROL-iv`); `span-expand-all` 1 (`CONTROL-v`); `subject-inverted` 1 (`CONTROL-ii`); `first-path-only` 1 (`CONTROL-iii`); a hand-built substring fix 0; engine absent 9; never-named control given a `NAMED-` row 9. The receipt carries no cleanup trap, matching the one it replaces. Its scratch repo is left under `TMPDIR`.

verify: sh L="$PWD/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"; [ -f "$L" ] || exit 9; w="$(mktemp -d)" || exit 9; g() { git -C "$w/d" -c user.name=r -c user.email=r@r -c commit.gpgsign=false "$@"; }; c() { g add -A && g commit -qm "$1"; }; git init -q "$w/d" || exit 9; mkdir -p "$w/d/core" "$w/d/docs" "$w/c" || exit 9; echo 1.0.0 > "$w/d/VERSION"; for f in a s o q r x; do echo "ANCH_$f" > "$w/d/core/$f.sh"; done; c base || exit 9; B="$(g rev-parse HEAD)"; echo pad >> "$w/d/core/a.sh"; c "fix: absorb PC-S890-FILE-TOUCHED" || exit 9; echo x >> "$w/d/core/o.sh"; c "fix: absorb PC-S891-THIRD-CLASS" || exit 9; echo "ANCH_s fixed" >> "$w/d/core/s.sh"; echo 1.1.0 > "$w/d/VERSION"; c "1.1.0 -- absorb PC-S892-SQUASH" || exit 9; echo "ANCH_r fixed" >> "$w/d/core/r.sh"; c "fix: unnamed" || exit 9; echo n > "$w/d/CHANGELOG.md"; echo 1.2.0 > "$w/d/VERSION"; c "1.2.0 -- absorb PC-S893-BRANCH" || exit 9; echo "ANCH_x fixed" >> "$w/d/core/x.sh"; c "fix: unnamed neighbour" || exit 9; echo y >> "$w/d/core/o.sh"; c "fix: absorb PC-S894-OVER-EXPAND" || exit 9; echo p > "$w/d/docs/p.md"; c "docs(plan): mention PC-S895-DOCS-CTL" || exit 9; T="$(g rev-parse HEAD)"; e() { printf -- '- **%s** -- control.\n' "$1"; shift; for p in "$@"; do printf -- '  verify: theirs_has core/%s.sh "ANCH_%s"\n' "$p" "$p"; done; printf '\n'; }; { printf '# l\n\n'; e PC-S890-FILE-TOUCHED a; e PC-S891-THIRD-CLASS s; e PC-S892-SQUASH q s; e PC-S893-BRANCH r; e PC-S894-OVER-EXPAND x; e PC-S895-DOCS-CTL s; e PC-S896-NEVER s; } > "$w/c/l.md" || exit 9; o="$(bash "$L" "$w/d" "$B" "$w/c" "$T" "$w/c/l.md" 2>/dev/null)"; k() { printf '%s\n' "$o" | awk -F'\t' -v l="$1" '$2==l && $1 ~ /^NAMED-/ {print $1; exit}'; }; n() { printf '%s\n' "$o" | awk -F'\t' -v l="$1" '$2==l {c++} END {print c+0}'; }; [ "$(n PC-S896-NEVER)" -gt 0 ] && [ -z "$(k PC-S896-NEVER)" ] || exit 9; f() { v="$(k "$3")"; echo "BL145-$1 $2=${v:-<no row>}" >&2; exit 1; }; [ "$(k PC-S891-THIRD-CLASS)" = NAMED-UPSTREAM-OFF-SUBJECT ] || f "CONTROL-ii-FILE-UNTOUCHED-NOT-OFF-SUBJECT" third PC-S891-THIRD-CLASS; [ "$(k PC-S892-SQUASH)" = NAMED-UPSTREAM ] || f "CONTROL-iii-GENUINE-SQUASH-TWO-PATH-DEMOTED" squash PC-S892-SQUASH; [ "$(k PC-S893-BRANCH)" = NAMED-UPSTREAM ] || f "CONTROL-iv-BRANCH-RELEASE-SPAN-DEMOTED" branch PC-S893-BRANCH; [ "$(k PC-S894-OVER-EXPAND)" = NAMED-UPSTREAM-OFF-SUBJECT ] || f "CONTROL-v-NON-RELEASE-SPAN-EXPANDED" over PC-S894-OVER-EXPAND; [ "$(k PC-S895-DOCS-CTL)" = NAMED-UPSTREAM-DOCS-ONLY ] || f "CONTROL-vi-DOCS-NOT-DOCS-ONLY" docs PC-S895-DOCS-CTL; case "$(k PC-S890-FILE-TOUCHED)" in ""|NAMED-UPSTREAM|NAMED-UPSTREAM-DOCS-ONLY|NAMED-UPSTREAM-CITED-ONLY|NAMED-UPSTREAM-AMBIGUOUS) f "i-RECEIPT-FILE-TOUCHED-SUBSTRING-UNCHANGED-READ-AS-ABSORBED" filetouched PC-S890-FILE-TOUCHED ;; esac; exit 0



## BL-195 — Check 2's suppression-lifetime arm reads a verdict the CURRENT gate has not yet written, and all four candidate remedies are refuted by measurement

**Operator decision, 2026-10-01: left open, receipt `manual`, no remedy rebuilt.** The reference
consumer archived `PC-S308` as `ADOPTED UPSTREAM (v0.568.0)`; that annotation is not evidence the
defect is fixed, because the stale read below still reproduces.

**Provenance.** `PC-S308-GATE-METRICS-CHECK2-STALE-VERDICT-READ-ORDER`, filed by the reference
consumer 2026-09-06. **This entry is FILED AND DELIBERATELY NOT FIXED.** The defect is real and
better evidenced than the filing claims; every remedy proposed for it — the filing's two, plus two
derived here — was built or measured and refuted. It is recorded so the next session does not
rebuild any of them.

**The defect, verified against the consumer's own committed history.** Check 2 invokes
`validate-suppression-lifetime.sh` (`core/skills/ai-dlc/steps/gate-validation.md:245`), which
decides whether a suppression's named check is still failing by reading the newest recorded
verdict in `gate-metrics.jsonl` (`core/scripts/validate-suppression-lifetime.sh:471`). That file
is written ONLY by Check 12 (`gate-validation.md:736`), which runs after. So Check 2 necessarily
reads the PREVIOUS gate's verdict, and a fix landing between two gates is invisible to it.

The filing's cited case reproduces exactly: the FAIL row at `2026-09-05T22:58:00Z` carries sha
`7729b544a…`, and `git merge-base --is-ancestor` puts that tree strictly BEFORE the reword fix at
`33f925bcf` (exit 0; reverse direction exit 1 as control).

**THE CONSUMER DIAGNOSED THIS ELEVEN DAYS BEFORE FILING IT, AND CHOSE TO SUPPRESS.**
`docs/escalations/pending.md:3684`, 2026-08-26: *"Check 16 itself passed cleanly THIS gate on its
own merits … but that PASS has not yet been recorded to `gate-log.md` (Check 12 runs after this
adoption), so `validate-suppression-lifetime.sh` still reads story 2.1 gate-3's real 23-finding
check-16 FAIL as the last recorded verdict and reactivates these two unrelated older entries."*
That entry's own options list reads *"(a) fresh SUPPRESSED for check 16, this gate only [chosen];
(b) investigate/fix the Check 12-before-Check 2 ordering instead"*. A sibling entry at the S305
sprint-review gate does the same on check 22. **The recurrence is the choice, not the mechanism.**

**Recurrence: 3 distinct gate events across 2 sprints (S305 ×2, S308 ×1),** derived by scanning
both escalation corpora for entries naming a Check-2 suppression-lifetime FAIL together with a
last-recorded-verdict cause; 4 entries resolve to 3 gates. Impossible-phrase control returns
nothing. **An earlier reading of this batch narrowed it to 1 and was wrong** — that reading rested
on an ancestry test which cannot answer the question, because it asks whether the FAIL row was
written before the fix, which is necessarily true of every entry: the row IS the record of the
failing gate. The staleness is in the READ, not the write.

**THE FINDING THAT OUTRANKS THE FILING'S OWN CLAIM.** The metrics file is not merely stale at
unlucky moments; it is the LOSSY artifact in principle. Check-2 verdicts, full population:

| source | PASS | FAIL |
|---|---|---|
| per-gate `*.verdict.json` | 158 | **38** |
| `gate-metrics.jsonl` | 93 | **3** |

**A 12.7× undercount**, and the cause is structural: a gate that FAILs Check 2 halts before
reaching Check 12, so the row recording that failure is never written. Control — check 16, which
does not halt the gate, agrees far better (18 verdict FAILs against 5 metrics FAILs). The arm
consults the one artifact that structurally cannot record the failures that matter most.

**THE FOUR REFUTED REMEDIES. Do not rebuild these.**

**(a) Re-sequence Check 2's read to after Check 12's write — A CYCLE.** Check 12's own instruction
(`gate-validation.md:750`) is to emit a row for *every other check the manifest loaded*, which
includes Check 2. Measured: 12 rows carry `"check":"2"`, against an impossible-id control of 0.
Check 12 cannot write until Check 2 has produced a verdict to record, so "read after the writer
writes" is self-referential.

**(b) Re-run the underlying check live — FAILS OPEN ON 22 OF 57 CHECKS.** `enforcement-map.yaml`
gives 22 ids `enforcer: []` against 35 with one (57 total, partitioning exactly; impossible-key
control 0): `1 1c 3 3a 4 6 7 8 9 10 11 11a 12 13 14 15 19 20 21 27 29 H1`. **`[core] 11` is
suppressed twice in the live corpus and has no enforcer to run.** Treating "cannot re-run" as PASS
acquits every suppression on those 22 ids; treating it as FAIL fabricates blocks on them. The 35
that do have enforcers resolve to distinct CLI contracts with no generic invocation, so (b) would
additionally need a hand-written per-check invocation table.

**(c) Refuse when the recorded row's `sha` is not current — DISARMS ON A SQUASH-MERGE CONSUMER.**
Over the live metrics: 11 distinct shas, **0 ancestors of HEAD**, 10 orphans, 1 unresolvable;
control `merge-base --is-ancestor HEAD HEAD` exit 0. The consumer squash-merges, so the commit a
gate records is orphaned by the merge that lands the work. This shape reports NOT-APPLICABLE for
every row on a healthy tree — a total disarm that reads as green. `tool-hazards.md` states the
general rule: never test whether work landed by ancestry in a squash-merge repo.

**(d) Read the CURRENT gate's `*.verdict.json` instead — NO JOIN EXISTS.** 198 verdict files carry
the right answer (the file the S305 entry names records `check_id 16 → PASS` at the exact gate
where the metrics said FAIL), and they cover every suppressed id including the ones (b) cannot
reach — `2` (196 files), `16` (195), `11` (69), `22` (69), `24` (1), `30` (1), impossible-id
control 0. But **96 distinct gate events in the metrics against 197 distinct verdict
`generated_at` values intersect at 9**, control (ts ∩ ts) = 96. `generated_at` is the
adjudicator's write time, not the gate's `ts`. With no key, the fix either wedges 87 of 96 gates
or falls back to the stale row and reintroduces the defect. `gate_nonce` identifies a file
uniquely (197 of 198) but is not available to the validator, and "newest verdict.json" picks the
wrong file within two hours at the S305 gate — the original defect one file over. The directory
is also absent on a fresh consumer.

**What a fix would actually require**, stated so the next attempt starts from the real
constraint rather than from the filing's framing: a gate-scoped identifier that both the verdict
artifact and the suppression validator can see, passed IN by the caller rather than discovered.
That is a change to Check 2's invocation line in a resident skill file plus a new flag, and it is
fail-open the moment one caller omits it. **Nothing here is a small fix, and the smallest honest
change is documentation** — Check 2's body stating that its verdict source is the PREVIOUS gate's
record, and the arm reporting the `ts` of the row it read so a false positive is legible when it
fires.

**The consumer-owned half is not upstream work.** Why the 2026-07-22 failure happened at all, and
whether their sprints should keep suppressing rather than escalating, is that consumer's own
carry-over.

**The smallest honest change shipped in v0.666.0; the defect stands.** The expiry FAIL now names
the `ts` of the row `latest_verdict` selected and the metrics file, and says that this is the
PREVIOUS gate's recorded verdict because Check 12 writes this gate's row after Check 2 runs.
`gate-validation.md` Check 2 and `escalations.md` state the same thing. Fixture arms 18a-18d in
`core/fixtures/suppression-lifetime/run.sh` pin the exact ts: the newest core row, not a newer
extension row, and not the last row read in file order. Mutants K (ts dropped) and L (last-read
ts) are killed. The stale read itself is unchanged, so this entry stays open and its receipt
stays `manual`: an `sh` receipt over the mitigation exits 0 and would score the entry
CLOSE-CANDIDATE for a defect that still reproduces. The fixture carries the mitigation.

verify: manual

## BL-301 — the gate runs no shipped fixture in the consumer layout, so a fixture red on every consumer ships green

**DEFECT.** Found by the batch 150 contract adversary. It discharges no consumer candidate.

**THE GAP `BL-299` FELL THROUGH.** The distribution's pre-push runs `core/fixtures/*/run.sh` in
the distribution tree. `install.sh` splits what shares a parent here, so `core/scripts/<x>`
lands at `scripts/ai-dlc/<x>` and `core/schemas/` at `.claude/schemas/`. A fixture that resolves
a sibling through the distribution's relative layout therefore passes here and fails on every
consumer. That is what happened to story-provenance's arm R, which went red in every consumer
install from 0.628.0 while every distribution push stayed green. The consumer found it on its
own tree, three releases later. The installer-driving fixtures here (`consumer-machinery-home`,
`layer-crosswalk-home`, `shipped-rule-version-floor` and five more, located by grepping
`core/fixtures/*/run.sh` for `scripts/install.sh`) each assert one property of the installed
tree. None of them runs the shipped fixture set there.

**THE SHAPE OF A FIX, AND WHY IT IS NOT A SMALL ONE.** A gate phase would install HEAD into a
`mktemp -d` consumer with `_bmad/`, then run every shipped fixture there through the consumer's
own installed runner, `core/git-hooks/pre-push`, which is the program a consumer runs. It has to
use that runner so that the pool and the verdict accounting match. The shipped set is the
fixtures carrying no `.dist-only` marker. The cost is a second full pass over most of the suite,
and the suite is pole-bound, so the phase has to be scheduled against the existing pole rather
than appended serially. **Measure that cost before choosing** between a full consumer-layout
pass and a pass limited to the fixtures whose read-set crosses a path that `install.sh` remaps.

**`verify: manual`, because no behavioural receipt is constructible at receipt scale.** The
property is that the GATE runs the shipped set in a consumer layout. The only behavioural test
is to seed a fixture that fails only in the consumer layout and run the gate, which means running
the suite from inside a receipt, and the receipt runner itself runs from inside that gate. A
grep of `.githooks/pre-push` for `install.sh` would be satisfied by a comment, and
`scripts/validate-backlog-receipts.sh` would correctly report it as PROSE-CLOSABLE. Close this
entry by hand on the release whose gate shows the new phase failing on a seeded consumer-only
fixture and passing on its removal.

verify: manual

## BL-375 — the read-set deriver needs root for `fs_usage`, and a scoped `sandbox-exec` tracer measured as a root-free replacement

**DEFECT.** Operator-scheduled on 2026-09-29 as its own release, after v0.665.0.
`core/scripts/derive-fixture-readsets.sh` requires root (`[ "$(id -u)" = "0" ]`) because `fs_usage`
does, so every read-set trace blocks a release on an operator `sudo` step.

**Measured at batch 173 on four fixtures** (`plan-shape`, `document-partition`,
`derivation-capture`, `check-24-adversarial-convergence`), with the tree pinned at 43306861 and
compared against the map the operator traced there with `fs_usage` plus atime:
- The scoped sandbox tracer saw every map row outside `.git/**` and `.gitignore`. It missed 14 or
  15 rows per fixture, all of them git internals. The four fixtures produced 0 sandbox reports under
  `.git/`, against 56 to 5579 under `core/` in the same windows. Those rows appear in all 218
  mapped fixtures.
- It saw three negative lookups `fs_usage` never recorded, which is the safe direction.
- The atime tracer added nothing the sandbox did not see (sandbox ∪ atime = sandbox on all four).
- Micro-probe: `cat`, `[ -f existing ]`, `[ -f missing ]`, `[ -d missing ]`, `stat`, `git
  rev-parse`, `ls` and `readlink` are all reported, as unprivileged. The impossible-token control
  read 0.
- Event loss: the scoped profile had 0 drop notices in 6 runs, idle and with two heavy fixtures
  concurrent. An unscoped `(allow default (with report))` dropped 64,673 messages on `check-24` and
  lost paths, so the scope is load-bearing.
- Cost: about +4% on `derivation-capture`.

**Profile:**

    (version 3)
    (allow default)
    (allow file* process-exec* (subpath "<TREE>") (with report))

**Extraction,** started BEFORE the fixture (`log show` afterwards returns 0 lines, and the
`(trace ...)` directive writes nothing). In zsh, `log` is a builtin, so call `/usr/bin/log`.
`<TREE>` must be the canonical `/private/tmp/...` path.

    /usr/bin/log stream --level debug --style compact \
      --predicate 'sender == "Sandbox" AND eventMessage CONTAINS "<TREE>/"'

Per line, `Sandbox: <proc>(<pid>) allow <op> <TREE>/<path>`: keep `file*` and `process-exec*` ops,
then apply the deriver's DAEMONS filter, `norm`, the sentinel drop and `drop_ignored`.

**Open before it replaces `fs_usage`:**
- Only 4 of 218 fixtures were compared. Add the sandbox tracer as a mode beside the existing one.
  Take ONE final `sudo` run that traces all 218 with both tracers in the same pass, and require the
  sandbox's miss set outside `.git/**` and `.gitignore` to be exactly 0. Then remove `fs_usage` and
  the root check.
- Establish whether the runner's content-key skip reads the `.git/**` rows. If it does, record them
  without root (e.g. a fixed set for every mapped fixture); do not simply drop them.
- `log stream --level debug` was tested only from an admin-group account.
- `sandbox-exec` is documented as deprecated. It works on macOS 27.2.
- A read by a process outside the sandboxed lineage (an XPC or launchd helper) is invisible by
  construction. The per-fixture process census saw only bash, cp, grep, cmp, python and awk.

The batch-173 harness is kept outside the tree at
`~/.claude/projects/-Users-n8-git-ai-dlc/b173-sandbox-tracer/`: `trace2.sh` (the scoped tracer),
`mktree.sh`, `micro3.sh`, `compare.sh` and `load.sh`. It is evidence, not the implementation.

Held note (batch 178): the comparison mode is BUILT and the operator's fixed command now parses:
`sudo bash core/scripts/derive-fixture-readsets.sh --all --tracer both` (or `--list "<fixtures>"`).
It needs root, runs each fixture ONCE as `sudo -n -u "$SUDO_USER" sandbox-exec` under both tracers,
prints `sandbox-missed` and `fs_usage-missed` per fixture, and ends `SANDBOX-MISSES-NOTHING` (0),
`SANDBOX-MISSES <n> path(s) across <m> fixture(s)` (1, paths listed in `$WORK/both.missed`) or
`REFUSED` (2). Every refusal in that mode is 2, including not-root and a linked worktree, and so is
compared < listed, naming each uncompared fixture and why. It never writes the map. Miss = fs_usage
minus sandbox, after excluding `.git`/`.git/**` by prefix and the `git check-ignore` set; the
tracked FILE `.gitignore` is NOT excluded. The deriver's header states each choice and its reason.
`core/fixtures/readset-skip` drives the verdict span, the refusals, and a full stub-world run whose
map md5 must not move, with a mutant deleting the exit to prove the md5 would move. NOT run with
root: whether root `log stream` sees a `sudo -u` child's Sandbox reports is unmeasured; if it does
not, every fixture reads `sandbox set empty` and the run REFUSES rather than passing. Stays open
for the operator's run. The receipt reads the entry's real close: no `fs_usage -w` and no uid-0
check left in the deriver while `sandbox-exec -f` remains. It reads 1 on this branch by design.

verify: sh D=core/scripts/derive-fixture-readsets.sh; [ -f "$D" ] || exit 9; B="$(grep -v '^[[:space:]]*#' "$D")"; grep -q 'sandbox-exec -f' <<<"$B" || exit 1; grep -q 'fs_usage -w' <<<"$B" && exit 1; grep -qF '"$(id -u)" = "0"' <<<"$B" && exit 1; exit 0

## BL-404 — the acknowledge hook's typed-invocation anchor depends on the harness's serialisation, and an updater call inside a pipeline session is asserted by no arm

**NOTE. Found at batch 178 by the S316 tip adversary.** `core/hooks/ai-dlc-acknowledge.sh:196` recognises a typed `/ai-dlc` or `/ai-dlc-update` only as `"role":"user","content":"<command-message>…</command-message>\n<command-name>/…`. Across the local transcripts all 301 typed-skill records carry that shape (negative control 0); the other user lines with a `<command-name>` are built-in commands with no `<command-message>`, and there are 0 array-content variants. If the harness changes how it serialises a typed command, typed updater sessions are denied writes under the pause again and Check 2z stops gating typed `/ai-dlc` sessions, and nothing in the tree would notice.

Second claim: the last-skill rule (`tail -1`) and the live `Skill` override (`:207-210`) mean a pipeline lead that calls `Skill(ai-dlc-update)` stops pausing writes until `/ai-dlc` is invoked again. Accepted by contract; `updater-session-signals` seeds only the reverse order (`run.sh:109-110`), so no arm asserts it.

Discharges no consumer candidate.

**Batch 181:** claim 2 landed in 0.699.0 (`updater-session-signals` asserts the other order, a typed `/ai-dlc` then `Skill(ai-dlc-update)`). Claim 1 stays open: its subject is the harness's transcript format, which no file in this tree contains.

verify: manual

The receipt is manual because its subject is the harness's own transcript format, which no file in this tree contains: a predicate keyed on the hook's regex would only check the regex against the copy the seeds were written from.

## BL-412 — `layer-reference-resolution` went red once under the pool on a close commit that touches none of its inputs, and the cause is not established

**NOTE. Seen at batch 179, not diagnosed.** The first gate of the second close commit (`d7cb330a`, which changed only `docs/backlog.md`, `docs/backlog.archive.md` and `.githooks/pre-push`) failed on one unit of 216 at pool width 16 and a 1-minute load near 40: mutant `hook-resolve-mention` read `w12shadow5=W` where the fixture expects `-`. That fixture reads none of the three files and its read-set rows name none of them. Run alone from the main checkout it passed three times (42 assertions, about 55s), and the unchanged commit passed a second gate with 216 of 216 ok. No ordering or timing construct in `vector.sh` or `worker.sh` was found that would explain it, and the recorded loaded cost is 148s against 55s solo. A load-dependent fault is a hypothesis, not a finding. The batch-179 got-vector did not survive: the hook's failure record (`.git/ai-dlc-fixture-failures`) is overwritten by the next red run.

**PARTIAL IN BATCH 185: EVERY RED RUN NOW RETAINS ITS OWN RECORD.** Both pre-push hooks copy the record, on a successful primary write only, to `.git/ai-dlc-fixture-failures.<UTC %Y%m%dT%H%M%SZ>.<pid>` and prune to the newest `FAILLOG_KEEP` copies of that exact shape. Hand-saved records under other names (`.clean` on this machine) are outside the anchored prune pattern. `core/fixtures/consumer-suite-pool` arm 2c and mutants `retain-off`, `retain-fixed-name`, `prune-off`, `prune-glob-wide` hold it. **This does not close the entry**: the cause was never established, and retention only guarantees that the next recurrence leaves its got-vector on disk. Read the newest stamped copy whose header names `layer-reference-resolution` when it recurs. A hand-saved copy is safe from the prune if its name gains a non-numeric suffix (`.keep`).

verify: manual -- retention is held by core/fixtures/consumer-suite-pool (arm 2c and its five mutants); the open half, the cause of the red, has nothing to score until a recurrence leaves a retained record.

## BL-430 — `docs/suite-pole-baseline.tsv`'s pool-12 block still names `ledger-reverify` at 628s, a unit that has since been sharded

**NOTE. Found at batch 185 while restating BL-005's pole paragraph.** The jobs-12 block of
`docs/suite-pole-baseline.tsv` (its data row and the v0.583.0 ratchet-history line) records
`ledger-reverify 628`, taken at `83747ef4` over 201 fixture directories. `ledger-reverify` has
since been sharded: `ledger-reverify-b`, `-c` and `-d` re-enter its `run.sh`, so the
`ledger-reverify` directory now carries one shard of the assertion set the 628s figure timed
whole. At pool 12 `scripts/validate-suite-pole.sh` therefore compares the live pole against a
figure taken on a different partition. Its pole-moved NOTE (`:611-613`) says so on a run where
another unit is longest, and it does not fail. The pool-16 block (`gate-adjudication-mutants`, v0.705.0) is current and
unaffected.

verify: manual -- re-taking the row needs the file's own calibration recipe: three serial full runs under `AI_DLC_FIXTURE_NO_SKIP=1` at pool 12. That forced full run is one the operator has not authorised, so no session can produce the measurement that would close this, and a receipt keyed on the row's text would close it on an edit with no measurement behind it.

