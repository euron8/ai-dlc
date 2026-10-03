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

**THE BATCH-116 BARE-`mktemp` LEAD IS DEAD, MEASURED AT BATCH 187.** The precedent it cites (now
`ledger-reverify.sh:1591-1597`) failed because a FIXTURE counted the host's whole `tmp.*`
population to ask whether one run had materialized a tree; prefixing the engine's directory made
that question answerable by name. A bare `mktemp` is harmful only to a reader of that kind.
`core/fixtures/reconcile-emit-report/run.sh` carries **0** readers of a `tmp.*` population
(control in the same invocation: 1 such reader elsewhere under `core/fixtures`), and the bare
calls now sit at `emit-report.sh:608`, `:669` and four more sites, each a private scratch file whose
path no arm inspects. Prefixing them would change nothing E1, E2, E8 or E9 observe, so it is not a
remedy for this entry and was not built. What remains open is claim (d) alone: the pool flake on
E1, E2, E8 and E9, with no named cause.

verify: manual

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

**Batch 186 prototyped the citation-key arm and did not build it.** A report-only
`OVERRIDE-CITED-CORE-DRIFT` row, keyed on a qualified grammar of core paths cited in an
override's body and fired when a cited file changes across the pull range. Run with the real
`layer-drift.sh` against the reference consumer's installed overrides on its 0.706.0 → 0.709.0
pull, it produced 17 hits under bare basenames. A qualified grammar cut that to 5, and the pull
range instead of each override's `base_sha` cut it to 1. That one hit, `gate-validation.md` cited
by the domain-sections override, is a false positive: 0 changed lines carry the tokens the
override relies on. True positives on real data: 0. The motivating Rule-8 case fires identically
with theirs set before the arm-E migration, so its hit comes from an unrelated prose edit, not the
migration. The arm would narrow nothing measurable, and `layer-drift.sh` is bootstrapping.
**Operator ruling, batch 186: do not build this arm.** The entry stays open on claim (b); a later
detector proposal must show a true positive on the consumer's real overrides before it is built.

verify: manual -- this entry records a gap, not a receipt. Do not close it on a green
`layer-drift.sh` run; that green is the defect.

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

**Ship gate, measured over the reference consumer's archive with close annotations stripped.** The base engine `c18897d9` and the fix engine `d7bdcc41` each emitted 576 rows over that population. 570 are byte-identical and 6 moved to `NAMED-UPSTREAM-OFF-SUBJECT`. Five of the six are true off-subject rows. Each is named only by `e939a925` (`v0.373.0`), whose 43-commit release span touches none of the five receipt paths: PC-S295-RETRO-LEAD-SOLO-EVAL-LLM-CHECK, PC-S297-RETRO-MD-CLAIMS-NONEXISTENT-GHA-WORKFLOW, PC-S297-VALIDATE-MANDATORY-RULES-CHECK3-CHECK4-DEAD, PC-S299-UNREGISTERED-DRIFT-SCAN-SKIPS-CORE-FIXTURES-AND-CORE-SCRIPTS and PC-S302-ADJUDICATION-RERUN-BASE-DISARMS-LC-A1. The archive annotates each of them FALSIFIED, ALREADY-FIXED or DUPLICATE at an earlier version. The sixth, PC-S298-SETUP-SUBSTITUTION-EATS-SITE-DECLARATION-COMMENT, is a genuine absorption. `362f6840` (`v0.144.0`) adds the fix to `core/skills/ai-dlc-setup/SKILL.md`, while the receipt anchors on a structural precondition, `core/team-roles/dev-escalated.md`. Its sibling PC-S298-SETUP-NEVER-INSTRUCTS-REMEDIATOR-MODEL-FILL is named by the same commit and stays NAMED-UPSTREAM, which is the in-commit control. The measured set is therefore 6 movers: 5 true, and 1 of a named class. When an author picks a receipt path as a precondition rather than as the subject, a genuine absorption reads OFF-SUBJECT, and only that author can tell the two apart. The row text allows for that case, and no suppression heuristic is built, for the same reason substring matching was refused. Over the live ledger at the sprint tip, 0 of 12 rows moved. The engines' wall-clock difference was not resolved: under load 12-100 each engine's spread was about 105s against a gap of about 5s.

**Receipt replaced again: the previous one exits 0 on the per-file fix (scored on the R1 tip under `set -uo pipefail`) while PC-S308 is still open, which would retire a live entry.** The new receipt drives the shipping `ledger-reverify.sh` over seven entries in one repo. Clause (i) is a core commit that touches the entry's receipt file and leaves the receipt substring unchanged. The receipt exits 0 only when that entry has a `NAMED-` row outside NAMED-UPSTREAM, -DOCS-ONLY, -CITED-ONLY and -AMBIGUOUS, so it exits 1 while the PC-S308 shape stays open. Five controls each exit 1 and name their own clause on stderr when they fail. (ii) A core commit touching no receipt file must read NAMED-UPSTREAM-OFF-SUBJECT. (iii) A squash-shaped release, on an entry with two receipt paths where only the second is touched, must read NAMED-UPSTREAM. (iv) A branch-shaped release must read NAMED-UPSTREAM; its fix parent names nothing, and the naming child changes only `CHANGELOG.md` and `VERSION`. (v) A non-release naming commit must read OFF-SUBJECT; an unnamed neighbour in the same span touched its subject. (vi) A docs-only naming must read DOCS-ONLY. (vii) A never-named control that gains a `NAMED-` row exits 9, and so does an absent engine. The controls run before clause (i), so a broken engine never reports as the open entry. Scored under `set -uo pipefail` from the repo root, in scratch copies of `core/` with every mutation asserted applied: R1 tip 1 (`i-RECEIPT-FILE-TOUCHED-SUBSTRING-UNCHANGED-READ-AS-ABSORBED filetouched=NAMED-UPSTREAM`); base `c18897d9` 1 (`CONTROL-ii`); `span-off` 1 (`CONTROL-iv`); `span-expand-all` 1 (`CONTROL-v`); `subject-inverted` 1 (`CONTROL-ii`); `first-path-only` 1 (`CONTROL-iii`); a hand-built substring fix 0; engine absent 9; never-named control given a `NAMED-` row 9. The receipt carries no cleanup trap, matching the one it replaces. Its scratch repo is left under `TMPDIR`.

verify: sh L="$PWD/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"; [ -f "$L" ] || exit 9; w="$(mktemp -d)" || exit 9; g() { git -C "$w/d" -c user.name=r -c user.email=r@r -c commit.gpgsign=false "$@"; }; c() { g add -A && g commit -qm "$1"; }; git init -q "$w/d" || exit 9; mkdir -p "$w/d/core" "$w/d/docs" "$w/c" || exit 9; echo 1.0.0 > "$w/d/VERSION"; for f in a s o q r x; do echo "ANCH_$f" > "$w/d/core/$f.sh"; done; c base || exit 9; B="$(g rev-parse HEAD)"; echo pad >> "$w/d/core/a.sh"; c "fix: absorb PC-S890-FILE-TOUCHED" || exit 9; echo x >> "$w/d/core/o.sh"; c "fix: absorb PC-S891-THIRD-CLASS" || exit 9; echo "ANCH_s fixed" >> "$w/d/core/s.sh"; echo 1.1.0 > "$w/d/VERSION"; c "1.1.0 -- absorb PC-S892-SQUASH" || exit 9; echo "ANCH_r fixed" >> "$w/d/core/r.sh"; c "fix: unnamed" || exit 9; echo n > "$w/d/CHANGELOG.md"; echo 1.2.0 > "$w/d/VERSION"; c "1.2.0 -- absorb PC-S893-BRANCH" || exit 9; echo "ANCH_x fixed" >> "$w/d/core/x.sh"; c "fix: unnamed neighbour" || exit 9; echo y >> "$w/d/core/o.sh"; c "fix: absorb PC-S894-OVER-EXPAND" || exit 9; echo p > "$w/d/docs/p.md"; c "docs(plan): mention PC-S895-DOCS-CTL" || exit 9; T="$(g rev-parse HEAD)"; e() { printf -- '- **%s** -- control.\n' "$1"; shift; for p in "$@"; do printf -- '  verify: theirs_has core/%s.sh "ANCH_%s"\n' "$p" "$p"; done; printf '\n'; }; { printf '# l\n\n'; e PC-S890-FILE-TOUCHED a; e PC-S891-THIRD-CLASS s; e PC-S892-SQUASH q s; e PC-S893-BRANCH r; e PC-S894-OVER-EXPAND x; e PC-S895-DOCS-CTL s; e PC-S896-NEVER s; } > "$w/c/l.md" || exit 9; o="$(bash "$L" "$w/d" "$B" "$w/c" "$T" "$w/c/l.md" 2>/dev/null)"; k() { printf '%s\n' "$o" | awk -F'\t' -v l="$1" '$2==l && $1 ~ /^NAMED-/ {print $1; exit}'; }; n() { printf '%s\n' "$o" | awk -F'\t' -v l="$1" '$2==l {c++} END {print c+0}'; }; [ "$(n PC-S896-NEVER)" -gt 0 ] && [ -z "$(k PC-S896-NEVER)" ] || exit 9; f() { v="$(k "$3")"; echo "BL145-$1 $2=${v:-<no row>}" >&2; exit 1; }; [ "$(k PC-S891-THIRD-CLASS)" = NAMED-UPSTREAM-OFF-SUBJECT ] || f "CONTROL-ii-FILE-UNTOUCHED-NOT-OFF-SUBJECT" third PC-S891-THIRD-CLASS; [ "$(k PC-S892-SQUASH)" = NAMED-UPSTREAM ] || f "CONTROL-iii-GENUINE-SQUASH-TWO-PATH-DEMOTED" squash PC-S892-SQUASH; [ "$(k PC-S893-BRANCH)" = NAMED-UPSTREAM ] || f "CONTROL-iv-BRANCH-RELEASE-SPAN-DEMOTED" branch PC-S893-BRANCH; [ "$(k PC-S894-OVER-EXPAND)" = NAMED-UPSTREAM-OFF-SUBJECT ] || f "CONTROL-v-NON-RELEASE-SPAN-EXPANDED" over PC-S894-OVER-EXPAND; [ "$(k PC-S895-DOCS-CTL)" = NAMED-UPSTREAM-DOCS-ONLY ] || f "CONTROL-vi-DOCS-NOT-DOCS-ONLY" docs PC-S895-DOCS-CTL; case "$(k PC-S890-FILE-TOUCHED)" in ""|NAMED-UPSTREAM|NAMED-UPSTREAM-DOCS-ONLY|NAMED-UPSTREAM-CITED-ONLY|NAMED-UPSTREAM-AMBIGUOUS) f "i-RECEIPT-FILE-TOUCHED-SUBSTRING-UNCHANGED-READ-AS-ABSORBED" filetouched PC-S890-FILE-TOUCHED ;; esac; exit 0



## BL-375 — the sandbox read-set tracer drops reports and omits fixtures on real runs, so the root-requiring `fs_usage` tracer cannot yet be retired

**RE-SCOPED ON THE OPERATOR'S BATCH-185 RULING: THE FIRST DELIVERABLE IS A SANDBOX TRACE THAT
DOES NOT DROP.** The sandbox mode is built: `--tracer sandbox` refuses root and runs every fixture
under `sandbox-exec`, and `operator-rulings.md` already requires sessions to trace with it. It is
not yet a replacement, because real `--list` runs lose reports. Recorded in the plan's resume block,
not re-measured here: at batch 183, 6 of 12 fixtures were OMITTED at load 7-10; at batch 184, 11 of
18 were OMITTED at load 3-8 with zero agent worktrees, with dropped-report counts from 7 to 1254.
Both maps were discarded. Load and worktrees alone do not explain the drops. Until a multi-fixture
`--list` run under the sandbox tracer finishes with no OMITTED line, `fs_usage` is the only tracer
that produces a committable map. Removing it, and running the `--tracer both` comparison, both wait
on that. The receipt below still names the end state, so it reads 1 throughout.

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

**Batch 186: the drops follow the stream, not the fixture, and a one-fixture `--list` dodges
them for most units.** Three sandbox runs at `89aef8b5`, no agent worktrees on disk. A 27-fixture
`--list` at 1-minute load 4.7 on 18 cores OMITTED 6, with drop counts 82 to 748. The 21 that
traced clean, re-run alone as one `--list`, OMITTED 2 different ones (`ledger-reverify` 73,
`procsub-staged-refusal` 432), both clean in the first run. Each of the 27 traced alone, as its own
`--list`: 20 clean, 7 OMITTED with 34 to 2061 drops (`apply-drift-refile`,
`enforcement-map-sites`, `procsub-staged-refusal-boot`, `reconcile-emit-report`,
`self-update-gate`, `suite-pole-guard`, `validator-arm-selection-b`). Load rose to 35 during that
pass from processes outside this repo, so it is not a clean low-load reading. The 20 clean
fixtures' rows were committed; every other fixture's rows are byte-identical. A second
one-at-a-time pass over those 7, at `895ac0df` and load 7.3 falling to 3.8, mapped 3 more
(`procsub-staged-refusal-boot`, `self-update-gate`, `suite-pole-guard`). The other 4 OMITTED again:
`apply-drift-refile` 39, `enforcement-map-sites` 763, `reconcile-emit-report` 81,
`validator-arm-selection-b` 228 drops. Those four dropped on every pass. Size does not predict it:
two carry 858 rows, the other two carry 50 and 52, and the 350-row `procsub-staged-refusal`
traced clean alone.

**PARTIAL IN BATCH 188 (0.715.0): `validator-arm-selection-b`'s drops have a measured mechanism
and a fix; the other three do not.** Measured by the batch-188 diagnosis hand in a scratch clone
of `25ac399d`:
- `validator-arm-selection-b` dropped 222-228 reports on every trace. Every drop fell in a 1-2s
  window running at 14k-46k reports/s with 26-118 concurrent `grep -r` from the fixture's inner
  `xargs -P 6` pools. Shard b's concurrency is the attribution pool, run twice, plus the seeded
  plain run dispatched beside it. A synthetic reproduction dropped at K=6 and K=12 concurrent
  greps, never at K=1 or K=2, and never serially at 26.6k reports, so concurrency is the variable
  and volume is not. At inner width 1 it traced clean from load 34.8: 0 drops, 956 paths, covering
  every committed non-`.git` row except 9 rows for files no longer in the tree, plus 122 new rows.
- `enforcement-map-sites` dropped 1445 reports on the diagnosis hand's run, made with the sibling
  pool at width 1. The knob does not reach it: its own pool is a hard-coded `JOBS=8`, so "at
  width 1" does not describe it. Its drops come from its `cp -R` seed.
- `apply-drift-refile` and `reconcile-emit-report` drop on load-dependent upstream events.

The fix: `core/scripts/derive-fixture-readsets.sh` launches every traced fixture as
`... env VAS_INNER_POOL_WIDTH=1 bash <run.sh>` on both launch lines, after `sudo -u` and
`sandbox-exec`. Under `fs_usage` and `--tracer both` the fixture runs through sudo, whose
env_reset strips an export or a prefix in front of it. Under `--tracer sandbox` no sudo is on the
path, so a prefix in front of `sandboxed` would survive there; the `env` form is used on every
path so that one spelling holds under all three tracers.
`core/fixtures/validator-arm-selection/run.sh` resolves `JOBS` once from
`${VAS_INNER_POOL_WIDTH:-6}`, refuses a value that is not an integer from 1 to 64 with exit 2
(more than 3 digits is refused before any numeric test, which a 20-digit value would overflow),
and prints `inner pool width: N`. The width changes the schedule, not the work, so a set traced
at width 1 is the set at width 6. The knob carries no `AI_DLC_` prefix as future-proofing against
the fixture env scrubs keyed on it; no scrub is on this path today.
Held by `validator-arm-selection` (phase `width`: unset gives 6, 1 gives 1, 64 gives 64; 0, `abc`,
65 and a 20-digit value exit 2; and a source-text check that both `xargs` pool sites read
`"$JOBS"` and `JOBS` is assigned once) and `core/fixtures/readset-skip` (under `--tracer
sandbox` a copy of the real deriver traces a probe that echoes the knob and must log `width=1`,
the same probe outside the deriver logs `unset`, and a deriver copy with the injection removed
fails the arm; under `--tracer both` the stub world's sudo strips the knob as env_reset does, and
fxa must log `width=1`, which the injection moved in front of sudo, the `sandboxed` launch
dropping it, and a `VAS_INNER_POOL_WIDTH=1 sandboxed` prefix each fail). The `fs_usage` launch
line runs only as root and is covered only by the operator's own run.
**The shipped knob reaches the traced run, but width 1 is NOT sufficient: the fixture still
drops.** Measured on two re-traces at 0.715.0 (`9c28d78e`), in the main checkout with no linked
worktree. In both, `$TRACE_ROOT/w/validator-arm-selection-b.log` line 2 reads
`inner pool width: 1`, so the injection worked.
- The first re-trace started at 1-minute load 24 and the stream dropped reports 7 times.
- The second started at load 6 and dropped 19 times. Load rose to 25 during that run from
  other work on the box.

The deriver omitted the fixture, failed its own `zero fixtures mapped` control, and wrote no map
both times. That is down from 222-228 drops at width 6, and still not zero. The diagnosis clone's
0-drop run at width 1 is a single sample. At width 1 shard b still runs two validators at once,
the seeded run at `:413` beside the attrib pool, so the K=2 synthetic, which was clean, is the
nearest analogue and not an equivalent. Stage 1 stays unmet for all four fixtures.

**BATCH 189: THE ARM-6 SERIALISATION LEVER IS STRUCK.** ~~Serialise the seeded run against the
attrib pool when traced.~~ Refuted by the one trace on disk (`validator-arm-selection-b`, 0.715.0,
inner pool width 1, 19 drop notices). It places 0 of the 19 in arm 6's concurrent window. Of the
19, 17 fall in the seed `cp -R` burst at `core/fixtures/enforcement-map-sites/seed.sh:27-34`,
which is one `cp` process at about 4000 reports per 100ms, a third of them xattr reads. One falls
in an I91/I94-shaped `grep` burst at 09:08:30 and one at a burst tail. This is ONE sample. Two
levers replace it:
- (a) **The validator cwd fix, `BL-436`, in 0.716.0.** Arms I81, I91, I94 and I95 of
  `scripts/validate-enforcement-map.sh` read the process cwd, so a seeded tree's validator run
  from the repo root grepped the LIVE tree. That trace carries 166,633 such live-tree grep
  reports. Once the validator `cd`s into its own tree, the seeded tree's greps land under
  `$TMPDIR`, outside the profile's subpaths, and are expected to leave the stream. That is a
  prediction from the mechanism. The lead's before/after trace of `validator-arm-selection-b
  enforcement-map-sites` on the release branch and on the base is the measurement.
- (b) **The seed copy form: measured, and no form ships.** Each form copied the four subtrees of
  `seed.sh:27-34` and was traced alone under the deriver's own sandbox profile and stream reader,
  3 reps per form, at 1-minute load about 28-37 on the base tree `9bbc5a50`. Every rep was
  byte-equivalent to an untraced `cp -R`. Reports per rep, then drop notices:
  `cp -R` 8719/8984/6600 (about 2850 xattr), 0/0/0; `cp -RX` 2981/3009/2992 (0 xattr), 0/0/0;
  `tar` about 28000, 0/47/68; `tar --no-xattrs --no-mac-metadata` about 6000, 0/0/0;
  `ditto --noextattr` about 10500, 33/0/17. **The control does not drop:** `cp -R` alone gave 0
  notices in 3 of 3 reps, so the 17 seed-burst drops in the fixture trace come from the burst
  coinciding with other traced load, not from the copy alone, and this differential cannot show
  that any form removes them. `cp -RX` cuts the burst to about a third of its reports with an
  identical read set (956 paths in each rep, 0 missing against the union of `cp -R`'s sets). It is
  the candidate to try inside a real fixture trace, and it is unproven.

**A TRACE CAN LOSE REPORTS WITH NO DROP NOTICE.** In the batch-189 seed measurement, `cp -R` rep 3
recorded 946 of the 956 paths it must have read, and 747 `file-read-data` reports against 956, with
ZERO `Messages dropped` notices. One sample. So a run with no OMITTED line and 0 notices is not
proof of a complete read set, and the deriver's loss guard keys only on the notice. This is an
open measurement: the close criterion needs a completeness control as well as a zero-notice count.

**Stage 1's close criterion, as the batch-189 contract states it:** three consecutive
multi-fixture `--list` traces under the sandbox tracer with no OMITTED line and 0 drop notices,
with a completeness control beside the notice count.

**Do NOT switch the stream to `--style ndjson` to cut the report rate.** Measured: it lost up to
two-thirds of per-pid coverage while printing zero `Messages dropped` notices. The deriver's loss
guard keys on that notice, so ndjson would turn an omitted fixture into a silently smaller
read-set.

Still open: `enforcement-map-sites`, `apply-drift-refile`, `reconcile-emit-report` and
`validator-arm-selection-b` drop, so no multi-fixture `--list` is yet guaranteed clean, and the
stage-1 deliverable is not met.

**BATCH 191 (0.720.0): A LOSS CANARY BESIDE THE DROP-NOTICE GUARD, AND `EMS_POOL_WIDTH=1` ON
EVERY TRACED LAUNCH.** Under `--tracer sandbox`, `core/scripts/derive-fixture-readsets.sh` now
omits a fixture when `comm -23 $fx.at $fx.fs` is non-empty, that is, when the atime leg saw a read
the stream never reported. The OMITTED line reads `LOSS CANARY: <n> path(s)` and names the file
listing them. It is a loss canary and claims no completeness: atime cannot see a lost stat, a lost
negative lookup, or a lost report on a file deleted before the scan. It runs under both stream
tracers, `sandbox` and `both`. Under `both` it marks the fixture UNCOMPARED, because a read that
both tracers lost is invisible to the fs_usage comparison.
Both launch lines now pass `env VAS_INNER_POOL_WIDTH=1 EMS_POOL_WIDTH=1 bash`, so a traced
`enforcement-map-sites` run is narrowed once that fixture reads the knob.

Held by `core/fixtures/readset-skip`:
- **Stub-world canary arm.** This arm needs no `log stream`, so it runs on every unprivileged run.
  The stub stream reports `run.sh` alone while fxa really reads `src/a.sh`. The fixture must be
  OMITTED with `LOSS CANARY: 1 path(s)` and 0 drop notices. With both paths reported it must map.
  A deriver copy with the guard deleted maps the lossy window, which kills that mutant. This arm is
  what keeps the guard from being a check that cannot fire.
- **Real-stream arm.** An 8-reader burst over 1500 files runs under the unscoped profile, which
  must omit with the canary count, and under the scoped profile, which must map. The guard-deleted
  mutant is also run. The arm SKIPs, naming which side was not exercised, when no attempt
  exercises both sides. The adversary's "scoped 0/0" did NOT reproduce here: 0 of 8 scoped
  attempts traced clean, at 1-minute load 8.3 to 26.8. Two standalone attempts gave 31 and 33
  notices with 218 and 152 canary paths. So on this box the real-stream arm SKIPs, and it will
  SKIP under the pre-push pool too. The stub-world arm carries the proof.
- **`--tracer both` canary arm.** The stub world's empty-stream run must name
  `LOSS CANARY: 2 path(s)` in its UNCOMPARED reason. A mutant scoping the canary back to
  `--tracer sandbox` loses the token.
- **Width arms.** These now require `ems=1` beside `width=1` under both `--tracer sandbox` and
  `--tracer both`. The four width mutants are re-anchored on the two-knob line.

**False-positive census, taken before the commit.** The run was `bash
core/scripts/derive-fixture-readsets.sh --list "<33 fixtures>" --tracer sandbox` in a clone of
`4ea6bb79` with the working deriver overlaid. The list was every 8th mapped fixture plus the five
stage-1 subjects. The map was restored afterwards. Load was sampled every 15s and joined by each
fixture's log mtime.
- 16 fixtures mapped with canary 0 and 0 drop notices, at load 7.7-37.4.
- 17 were OMITTED for drop notices, with 3 to 2215 notices each.
- The canary fired on exactly one fixture, `validator-arm-selection-b`: 37 paths, beside 1863
  notices.
- The canary fired on 0 of the 16 zero-notice fixtures, so the false-positive set is empty and
  no narrowing was needed.
- The one zero-notice firing observed was a synthetic single-reader scoped burst over 1500 files.
  It produced 4 canary paths, 3 absent from the raw stream entirely and 1 present only as a prefix
  of other names (`d/f52` against `d/f520`...). That was a real silent loss, the case the batch-189
  `cp -R` rep 3 showed.

The stage-1 subjects in that run:
| fixture | drop notices | load |
|---|---|---|
| `enforcement-map-sites` | 739 | 15.8 |
| `enforcement-map-sites-b` | 1002 | 13.7 |
| `enforcement-map-sites-c` | 871 | 21.6 |
| `validator-arm-selection` | 2215 | 30.4 |
| `validator-arm-selection-b` | 1863, canary 37 | 42.1 |

**Stage 1's revised close criterion:** three consecutive multi-fixture `--list` traces under the
sandbox tracer, each covering `enforcement-map-sites`, `enforcement-map-sites-b`,
`enforcement-map-sites-c`, `validator-arm-selection` and `validator-arm-selection-b`. Each trace
must show:
- no OMITTED line;
- 0 drop notices;
- canary 0;
- an assertion count per fixture equal to an untraced run's;
- a peak 1-minute load of at least 4.5 during the trace.

The loss canary replaces the "completeness control" the batch-189 contract asked for, with the
limits stated above.

verify: sh D=core/scripts/derive-fixture-readsets.sh; [ -f "$D" ] || exit 9; B="$(grep -v '^[[:space:]]*#' "$D")"; grep -q 'sandbox-exec -f' <<<"$B" || exit 1; grep -q 'fs_usage -w' <<<"$B" && exit 1; grep -qF '"$(id -u)" = "0"' <<<"$B" && exit 1; exit 0

**BATCH-189 BEFORE/AFTER TRACE, ONE SAMPLE PER SIDE.** `bash core/scripts/derive-fixture-readsets.sh --list "validator-arm-selection-b enforcement-map-sites" --tracer sandbox`, main checkout detached at each sha in turn, map restored and nothing committed. Base `9bbc5a50` (load 4.52): `validator-arm-selection-b` OMITTED with 108 drop notices, `enforcement-map-sites` OMITTED with 894. Tip `946fb8ce`, carrying the BL-436 cwd fix (load 11.46): `validator-arm-selection-b` CLEAN, `enforcement-map-sites` OMITTED with 1036. Lever (a) moved the fixture it was predicted to move, at the higher load; one sample per side is not a close. `enforcement-map-sites` still drops on its seed `cp -R` burst, where no copy form was shown to help. Stage 1 and the three-consecutive-clean-traces criterion with a completeness control stand.

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

## BL-438 — QA writes a verdict vocabulary and a file name that gate-validation.md Check 1 does not read

**NOTE.** Measured by the batch 189 contract adversary on the reference consumer's
`docs/reviews/s316/` and re-counted read-only there for this entry. `qa.md:303` prescribes
`docs/reviews/s<N>/<story-index>-gate2-qa.md`; of the 20 QA files in that directory, 0 carry that
name (`ls | grep -c -- '-gate2-qa.md'`) and all 20 are named `<idx>-qa-validation.md` or
`<idx>-qa-validation-p<k>.md`, against 21 `-code-review` files as the same-directory control. 18
of the 20 carry a column-0 `Verdict: PASS` line (`grep -qE '^Verdict: PASS'`), and 19 of 20 carry
a PASS on a line Check 1's pattern matches. `gate-validation.md` Check 1 reads verdict values from
the set `code-reviewer.md` declares under `## Verdict`, where only `APPROVED` passes, and `qa.md`
declares no `## Verdict` set of its own. So a QA verdict of `PASS` is outside the I112 set, and the
name the role prescribes is one this consumer never wrote. One file (`1b-qa-validation.md`) reads
NEEDS_REWORK and one (`4b-qa-validation.md`) matches Check 1's pattern twice. This is why gate 2
ships serial-only in BL-437: a QA shard merge would have had to choose a vocabulary first.

verify: manual -- the remedy is a choice between giving qa.md its own declared verdict set and Check 1 a second set, or binding QA to the code-reviewer set; either is a contract change across a consumer's existing review files and is the operator's to make.

## BL-439 — the read-set map carries pseudo-path rows such as `<string>` and `sub/<unknown>`, which name no file

**NOTE.** All three tracers record a failed lookup on a placeholder argv string a fixture hands
its subject, so the map carried rows naming no file. The rows are cosmetic: the runner keeps
only manifest paths that pass `[ -f ]` (`.githooks/pre-push:578`), so such a row can never
select or skip a fixture. They read like a tracer fault, though.

Shipped: `readset_drop_pseudo` in `core/scripts/derive-fixture-readsets.sh`, between
`READSET_PSEUDO_BEGIN`/`END`, sits at the one call site where the atime, stream and fs_usage
sets meet, before `drop_ignored`. It drops a path only when its LAST component is a whole
`<...>` token (`^<[^/]*>$`) AND nothing by that name exists in the trace tree (`-e` or `-L`).
The colon-shaped argv rows (`file:/var/...`, `<hex>:core/...`, `HEAD:core/...`) are deliberately
not filtered. They are negative lookups the runner never hashes, and telling a `rev:path` argument
from a real file with a colon in its name needs its own design.

Held by `core/fixtures/readset-skip`: in the `--tracer both` stub world six seeds go into both
tracers' lists, and `fxa.set` must drop `<string>` and `sub/<unknown>` and keep `src/missing.sh`
(absent), `a<b>c` and `d/<real>` (present) and `e<f>g.sh` (absent). That last seed is the only
one separating the fix from an unanchored `<[^/]*>`. Five mutants each fail only that arm: the
filter removed (`111111`), a whole-path anchor (`011111`), the unanchored pattern (`001110`), an
existence-only filter (`000110`), and the filter on the sandbox set only (`111111`).

The receipt extracts the shipped span, drives it over the same six seeds against a seeded tree,
and requires the call at the meeting point. Scored under `bash -c 'set -uo pipefail; ...'` from a
copy of the deriver: the fix 0; base `4ea6bb79` 1; each of the five mutants 1.

verify: sh D=core/scripts/derive-fixture-readsets.sh; [ -f "$D" ] || exit 9; t="$(mktemp -d)" || exit 9; mkdir -p "$t/tree/d" "$t/tree/sub" && printf x > "$t/tree/a<b>c" && printf x > "$t/tree/d/<real>" || exit 9; sed -n '/^# READSET_PSEUDO_BEGIN$/,/^# READSET_PSEUDO_END$/p' "$D" > "$t/span"; n="$(grep -c 'readset_drop_pseudo()' "$t/span")" || n=0; [ "$n" -eq 1 ] || exit 1; c="$(grep -c 'readset_drop_pseudo | drop_ignored > "\$WORK/\$fx.set"' "$D")" || c=0; [ "$c" -eq 1 ] || exit 1; printf '%s\n' '<string>' 'sub/<unknown>' 'src/missing.sh' 'a<b>c' 'd/<real>' 'e<f>g.sh' > "$t/in"; out="$( TREE="$t/tree"; . "$t/span"; readset_drop_pseudo < "$t/in" | tr '\n' ' ' )"; [ "$out" = "src/missing.sh a<b>c d/<real> e<f>g.sh " ] || exit 1; exit 0

**LANDED (v0.720.0, verified TBD).**
