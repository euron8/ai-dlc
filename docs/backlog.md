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
`:1718`, the RAW-lines arm `:2294`, each shifting further with this release. 73 live `<(` remain across
28 fixture files, so a lint cannot ship yet.

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

## BL-099 — the exec-bit audit is one-directional, so a consumer file that upstream STOPPED shipping executable is never reported

**`apply.sh`'s EXEC-BIT AUDIT is LEVEL-triggered and covers exactly one of the two directions
it could.** It walks `git ls-tree -r "$THEIRS" -- core/`, keeps `$1=="100755"`, and reports every
one whose consumer copy is not executable. There is no mirror arm: a path upstream ships
`100644` whose consumer copy IS executable produces no finding anywhere, ever.

Measured, with a control in the same invocation: `100644` occurs three times in `apply.sh` and two
of those are comment prose — the only live one is the `chmod -x` inside `sync_mode_from_theirs()`,
which runs only on a file being APPLIED. `100755` occurs eight times, and both audit arms
(`apply.sh:878`, `apply.sh:1081`) test it alone.

**The asymmetry matters because the two directions have different backstops.** A file that should
be executable and is not gets caught on every subsequent pull, whatever earlier release left it
that way — that is what LEVEL buys. A file that should NOT be executable and is gets caught only
if some pull happens to APPLY it. `v0.423.0` closed the classifier half of that (a path whose
content matches theirs and whose bit does not now routes to a bucket that applies, so
`sync_mode_from_theirs` runs and `chmod -x` fires), but a bit left set by a pull that predates
that fix is still invisible, and nothing will look at it again.

The consequence is smaller than the `100755` direction — an over-permissive mode rather than an
inert validator — which is why this is filed rather than fixed inside `v0.423.0`. It is
nonetheless a hole in a check whose own header says "LEVEL, NOT EDGE ... an event-driven audit
would never look at it again".

**Candidate fix**: a second `awk` arm over the same `ls-tree` output keeping `$1=="100644"` and
reporting consumer copies that ARE executable. One walk, two filters — the enumeration is already
paid for. False-positive set NOT yet measured; that measurement is the first thing this entry
owes, because a consumer tree may hold executable copies for reasons this driver did not create.

**The receipt below is TEXT-KEYED, deliberately, and its weakness is stated rather than hidden.**
Driving `apply.sh` end-to-end needs the harness the `apply-*` fixtures carry and does not fit a
one-liner. It extracts the `NOEXEC` command substitution, STRIPS COMMENTS, and requires a
`100644` to survive — so the obvious prose close does not work: measured, a seeded
`# seeded: a 100644 arm` comment leaves it at exit 1, while a seeded `awk` arm takes it to 0.
It still cannot tell a real arm from any other live mention of the token in that block. The
proper proof belongs in a fixture that drives the audit.

Tiered **DEFECT**.

Found while closing `BL-033` at `v0.423.0`; not a `PC-` candidate, so it ranks below the
PC-backed set.

verify: sh P=core/skills/ai-dlc-update/reconcile/apply.sh; [ -f "$P" ] || exit 9; B="$(awk '/^NOEXEC="\$\($/{f=1} f{ sub(/#.*/,""); print } f && /^\)"$/{exit}' "$P")"; grep -q '100755' <<<"$B" || exit 1; grep -q '\[ -x' <<<"$B" || exit 1; grep -q '100644' <<<"$B"

## BL-100 — `--untangle` gives a mode-drifted consumer copy the same verdict as a correct one

**`preclassify.sh`'s `--untangle` mode buckets on `ours_h = base_h` and that comparison is
content-only**, so a consumer file holding the right bytes with the wrong exec bit reads
`ALREADY-AT-THEIRS` — "consumer never touched it, nothing to untangle".

Driven through the shipping script against this distribution as `DIST` with `HEAD` as both base
and theirs, and a synthetic consumer. The subject the population itself selects first is
`core/git-hooks/pre-push`, which maps to the consumer's `.githooks/pre-push`:

```
consumer copy 755, right content   ALREADY-AT-THEIRS      <- control
consumer copy 644, right content   ALREADY-AT-THEIRS      <- the finding: same answer
```

**The control and the subject returning the SAME value is what the finding IS here**, and it is
worth saying plainly because a control that agrees with the verdict is normally the sign of a
broken probe. Not in this shape: the claim is that the arm cannot discriminate, so the two arms
of the probe agreeing is the positive result. The probe is shown to be live by its own `exit 9`
guards — an empty row set, an unresolvable blob, or a control that is not `ALREADY-AT-THEIRS`
all abort rather than pass.

**The consequence is bounded by a backstop, which is why this is not a BLOCKER.** `--untangle`
is a one-time Phase-2 migration, and any later ordinary pull runs the level-triggered EXEC-BIT
AUDIT, which does cover `core/git-hooks/pre-push` in the `100755` direction. So the wrong verdict
is `--untangle`'s own report rather than a permanent state. In the `100644` direction there is no
backstop at all — see `BL-099`.

**Remedy NOT decided, deliberately.** `--untangle`'s three buckets are `UPSTREAM-ONLY-ADD`,
`ALREADY-AT-THEIRS` and `BOTH-CHANGED->CLASSIFY`, and it is not established which a mode-drifted
copy should take: it is not a content tangle, so `BOTH-CHANGED->CLASSIFY` overstates it. The
receipt therefore asserts only that the bucket is NOT `ALREADY-AT-THEIRS`, which any of the
plausible remedies satisfies. Whoever takes this decides the bucket first.

Note the `v0.423.0` conjunct is NOT reusable as-is: `mode_at_theirs()` reads `$THEIRS`, and in
`--untangle` base and theirs are the same ref by construction, so the helper resolves but answers
a question about a ref the mode never came from. Re-derive rather than copying the call.

Tiered **DEFECT**.

Found while closing `BL-033` at `v0.423.0`; not a `PC-` candidate, so it ranks below the
PC-backed set.

verify: sh P=core/skills/ai-dlc-update/reconcile/preclassify.sh; [ -f "$P" ] || exit 9; H="$(git rev-parse HEAD)" || exit 9; C="$(mktemp -d)" || exit 9; u() { bash "$P" . "$H" "$H" "$C" --untangle 2>/dev/null; }; R="$(u | LC_ALL=C awk -F'\t' '$1=="U"{print $2 "\t" $3}' | while IFS="$(printf '\t')" read -r cp cons; do [ "$(git ls-tree "$H" -- "$cp" | cut -c1-6)" = 100755 ] && { printf '%s\t%s\n' "$cp" "$cons"; break; }; done)"; [ -n "$R" ] || { rm -rf "$C"; exit 9; }; CP="$(printf '%s' "$R" | cut -f1)"; CO="$(printf '%s' "$R" | cut -f2)"; mkdir -p "$C/$(dirname "$CO")" || { rm -rf "$C"; exit 9; }; git show "${H}:${CP}" > "$C/$CO" 2>/dev/null || { rm -rf "$C"; exit 9; }; b() { u | LC_ALL=C awk -F'\t' -v p="$CP" '$2==p{print $4}'; }; chmod 755 "$C/$CO"; [ "$(b)" = ALREADY-AT-THEIRS ] || { rm -rf "$C"; exit 9; }; chmod 644 "$C/$CO"; D="$(b)"; rm -rf "$C"; [ "$D" != ALREADY-AT-THEIRS ]

## BL-092 — the rev-path defence is keyed on a `core/` prefix, so a non-`core/` distribution path reads as a missing consumer subject

**The rev-path defence is keyed on a `core/` PREFIX, so a distribution path that does not start
with `core/` is still read as a missing consumer subject.** `receipt_path_tokens()` at
`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:611` splits on non-path bytes, and the
four `case` prefixes then reject the `core/…` half of a rev-spec. A rev-path whose right side is
`docs/…`, `.claude/…` or `_bmad-output/…` has no such half. Measured at HEAD: a receipt naming
`$THEIRS:docs/backlog.md` yields `[ docs/backlog.md]` and `$THEIRS:.claude/rules/tool-hazards.md`
yields `[ .claude/rules/tool-hazards.md]` — both reported as absent consumer subjects when both
are distribution paths at a ref. **The shipped comment at `:599-600` asserts the opposite** —
"its distribution half fails the prefix test" — which is false for exactly these spellings, so
the file documents a defence it does not have.

**ZERO INSTANCES REPRODUCE TODAY, AND THAT IS THE ENTRY'S POINT, NOT A REASON TO SKIP IT.** All
10 rev-path right-hand sides in the reference consumer's 25-receipt live corpus are `core/`
prefixed (control: 48 of 48 rev-specs across the 70-receipt live + archive corpus begin `core/`),
so the guard is correct on every receipt anyone has written. It fails on the first receipt that
names a distribution `docs/` path at a ref, and it fails silently, by downgrading a close that
receipt had earned. This is the latent half of `BL-081`, separated from it deliberately:
`BL-081`'s title, mechanism, evidence and receipt are all specific to the
`core/scripts/<x>` → `scripts/<x>` substring, and that half is dead.

**Why this receipt.** It drives the shipping function rather than grepping the comment that
states the claim, because the comment is the thing that is wrong. It asserts both directions in
one run — the `docs/` rev-path must stop being reported AND a genuinely absent consumer path
must still be reported — so a fix that deletes the guard fails it.

**The probe sets `LR_STAGE`, because 0.651.0 made it part of the calling contract.**
`receipt_absent_subjects` now stages its tokens under the directory `lr_stage_ready` makes in the
main shell, and returns 3 without one. The first 0.651.0 gate failed R4 on this receipt, which
read exit 9 at its control and measured nothing.

verify: sh S=core/skills/ai-dlc-update/reconcile/ledger-reverify.sh; [ -f "$S" ] || exit 9; D="$(mktemp -d)" || exit 9; trap 'rm -rf "$D"' EXIT; mkdir -p "$D/c/docs" "$D/s" || exit 9; printf 'x\n' > "$D/c/docs/present.md" || exit 9; f="$(awk '/^receipt_path_tokens\(\) \{/,/^\}/' "$S")"; [ -n "$f" ] || exit 9; printf '%s\n' "$f" > "$D/lib.sh"; grep -q 'receipt_path_tokens()' "$D/lib.sh" || exit 9; grep -q 'receipt_absent_subjects()' "$D/lib.sh" || exit 9; bash -n "$D/lib.sh" 2>/dev/null || exit 9; probe() { CONSUMER="$D/c" LR_STAGE="$D/s" bash -c '. "$1"; receipt_absent_subjects "$2"' _ "$D/lib.sh" "$1" 2>/dev/null; }; ctl="$(probe 'grep -q x "$CONSUMER/docs/gone.md"')"; [ -n "$ctl" ] || exit 9; pres="$(probe 'grep -q x "$CONSUMER/docs/present.md"')"; [ -z "$pres" ] || exit 9; bad="$(probe 'git -C "$DIST" show "$THEIRS:docs/backlog.md" | diff - x')"; [ -z "$bad" ]

## BL-087 — ANSWERED: `PreToolUse` does NOT fire on a tool call that fails INPUT VALIDATION, so a guard whose predicate is the malformation is unbuildable

**THE ANSWER.** A tool call whose input fails the tool's own schema is rejected before any hook
sees it, and it is invisible to the hook system ENTIRELY — not merely to `PreToolUse`. Measured
on **Claude Code 2.1.266**; a refactor of the dispatch chain could move it, which is why the
build is named.

**The measurement, with its positive control in the SAME session.** A scratch project driving
real Claude Code as `claude -p --settings <scratch>/settings.json`, hook body three lines
(append stdin to a file, exit 0). The decisive arm put both calls in one session, so the control
cannot differ in registration, settings, model or session from the test:

```
Read {"path": "target.txt"}        schema-invalid   -> InputValidationError, NO hook payload
Read {"file_path": "target.txt"}   well-formed      -> executed, ONE hook line
```

With `PreToolUse`, `PostToolUse` and `PostToolUseFailure` all registered on `Read`
simultaneously, a schema-invalid call produced **zero lines across all three**. An
isolated malformed-only run wrote zero; an isolated well-formed-only run wrote one.

**The mechanism agrees and is the weaker source.** In the shipped bundle, dispatch is a hook
middleware chain whose INNERMOST step is the function carrying both `inputSchema.safeParse` and
the `InputValidationError` emission — so the chain's outer hook handlers are never entered for a
call that fails it. Controls on the extraction: `PreToolUse` 107 hits, `InputValidationError`
11, impossible token 0. That reading is what extends the result from `Read` to all tools, and it
is minified text ABOUT a program rather than the program; the measurement covers `Read` on
2.1.266 and nothing more.

**Subject substitution, stated because the entry prescribed `AskUserQuestion`.** That tool is
not offered under `claude -p`, so the model emitted no tool call at all — zero hook lines with
zero evidentiary value, which is the empty-file-without-a-control failure this repo names.
`Read` is valid because the validation site is shared by every tool. The literal 1-option
`AskUserQuestion` case needs an interactive run; nothing in the mechanism suggests it differs.

**"MALFORMED" IS TWO CLASSES AND ONLY ONE IS MEASURED.** `coerceInput` is an optional per-tool
hook that runs BEFORE `safeParse`, and its telemetry has a `coerced_still_invalid` outcome, so
it is permitted to fail. Hook-invisible: anything `safeParse` still refuses after coercion, or
with no `coerceInput` at all (measured: `Read` with `{"path": …}`), plus unparseable JSON
rejected upstream. Hook-visible: anything a tool's `coerceInput` repairs into a valid shape —
**existence follows from the mechanism; there is NO measured instance.** The nine `coerceInput`
implementations are **not enumerated**, so which malformations are visible cannot be predicted
from this entry. A candidate instance was measured and RETRACTED: re-reading the raw wire bytes
with `repr()` showed the input was a STRING containing brackets, schema-valid on arrival and
failing at the filesystem, not an array being coerced.

**THE DOCUMENTATION HAS MOVED SINCE THIS ENTRY WAS FILED, AND THE SENTENCE IT RESTED ON IS
GONE.** Re-checked: the hooks reference 301s to a new host, and `PreToolUse` now reads only
"Before a tool call executes. Can block it." The quoted "after Claude creates tool parameters
and before processing the tool call" is **deleted**. The ordering is still unstated, so the
entry's conclusion holds — but it no longer leans either way, and a session citing that sentence
is citing text that no longer exists.

**WHAT IS UNBUILDABLE, AND WHAT IS NOT AT RISK TODAY.** The unbuildable class is a `PreToolUse`
guard whose predicate is the malformation itself — the `<2`-option `AskUserQuestion` deny
dropped at v0.407.0, and any "refuse a call the schema will reject anyway" guard. **Nothing
shipped depends on it.** Derived over `templates/settings.json.template`: all five `PreToolUse`
groups (`ctx_*` MCP tools; `Edit|Write|MultiEdit`; `Agent|Task`; the acknowledge matcher; `*`)
read `.tool_input.<field>` on a call they assume is already valid — each decides on CONTENT,
none on VALIDITY. The only `AskUserQuestion` matcher in the template is under `PostToolUse`
(`ai-dlc-answer-capture.sh`), which records answers to SUCCESSFUL calls. A grep for
`tool_input.questions`/`.options` across `core/hooks/` returns 0 against a control of 9 files
containing `tool_input`. So this entry closes a question and forecloses a future design; it
fixes no live defect, and it ships as a recorded answer rather than as code.

**The rejections are real and reachable**, which is what makes the experiment cheap to validate:
parsing session transcripts finds `<2`-option `AskUserQuestion` calls that received an
`InputValidationError` tool_result with `is_error: true`. The reference consumer's sprint 305
carried three, one per session, each losing an operator decision to a compaction within minutes.

**Where it came from.** RC-3 of `docs/plans/graph-s305-triage.md` filed a `PreToolUse` deny on a
`<2`-option `AskUserQuestion`. It was DROPPED at v0.407.0 on the operator's decision, on the
grounds that it could not be shown able to fire AND would duplicate a rejection the lead already
sees in-band. The second ground is independent of this question; only the first depends on it.

**The experiment RAN and the answer is at the top of this entry.** The prescription was right
about method and wrong about one detail: `AskUserQuestion` cannot serve as the subject headless.
The general lesson is the one this repo already carries — an empty hook file is evidence only
beside a positive control that wrote to the same file, in the same session, through the same
registration.

**This entry stays LIVE and is not a fix.** There is nothing to ship: the answer is recorded,
no shipped guard depends on it, and the next author of a malformation-predicated guard needs to
meet this text before building. Its remaining unmeasured half is the coercion partition — nine
`coerceInput` implementations unread, and no measured instance of a repaired call.

  verify: manual

---

## BL-006 — the PLANS corpus and the CONSUMER's own ledger are still unbounded

**NARROWED at v0.418.0. The original subject is discharged; two subjects are not, and this entry
is those two.** `docs/backlog.md` is now bounded by `scripts/validate-backlog-size.sh` (arm `B1`,
`AI_DLC_BACKLOG_MAX_ENTRIES`, default 100), registered as a `step` in `.githooks/pre-push`. What
follows is what that arm does NOT reach. **An entry with two subjects expires only when both do**,
and the receipt below is a conjunction for exactly that reason — it exits 0 only when both halves
are discharged, so no single-corpus fix can retire this entry.

**`docs/plans/` is unbounded and the ledger ceiling does not touch it.**
`scripts/validate-plan-shape.sh` has no size arm at all: its only `wc -l`, at `:131`, resolves a
cited line number, and it contains no `wc -c`. Re-derived on this tree —
`docs/plans/retire-graph-consumer-layer.md` is **384817 bytes** against a **17021-byte median
across 29 plans**, a 22.6x ratio, and no push has ever failed over it. (The figures this entry
was filed with, a 16726-byte median across 23 plans, have drifted; the ratio has not.) That
validator is already standalone and already runs at pre-push (`.githooks/pre-push:117`), so the
arm has a home that costs no suite-pole wall clock.

**The CONSUMER's own push-candidate ledger is unbounded, and the distribution-side arm reaches no
consumer by construction.** `core/skills/ai-dlc-update/SKILL.md:1723-1724` records the reference
consumer's ledger at **2830 lines / 220 KB / 50 entries, of which only 39 are still classified** —
the state this whole pattern was forked from. `core/skills/ai-dlc-update/reconcile/ledger-rotate.sh`
carries no ceiling of any kind. `docs/backlog.md` does not ship: `install.sh` copies from
`core/scripts/`, never from top-level `scripts/`, so `validate-backlog-size.sh` is
distribution-only and a consumer inherits nothing from it.

**This entry previously cited `SKILL.md:1678` for those figures and that citation was WRONG-TARGET.**
`:1678` is prose about a checker obeying an over-wide declaration; `2830` occurs at `:1723`.
It is the `v0.390.0` class — the citation RESOLVES, so `validate-plan-shape.sh`'s resolvability
arm passes it, and a dangling-ref detector is blind to a wrong-target ref by construction.

**WHAT A `CLOSE-CANDIDATE` ON THIS ENTRY WOULD AND WOULD NOT MEAN.** The receipt's consumer half
drives shipped `reconcile/*.sh` against two synthetic ledgers inside a clone. It therefore
certifies that **the DISTRIBUTION ships a program that refuses an oversized ledger** — never that
any consumer's ledger is actually bounded, which no distribution-side receipt can observe. A
consumer runs its own installed engine, so the bound arrives only on the pull that carries it.
Read a green row here as "the refusal is shipped", and confirm the consumer separately. This
entry has already produced one false `CLOSE-CANDIDATE`; this paragraph exists so the next one is
not merely a misread.

**Put the consumer-side ceiling where a LEDGER PATH is the argument.** Measured over the 22
`reconcile/*.sh`: four accept a bare ledger path (`ledger-rotate.sh`, `adopt-extension-checks.sh`,
`lib.sh`, `relabel-extension-checks.sh`) and the other 18 exit non-zero on any ledger, being usage
errors. `ledger-reverify.sh` is one of the 18 — its argument order is a `<dist> <base> <consumer>
<theirs>` pull triple — so a remedy landing inside it would read STILL-LIVE against the receipt
below. `ledger-rotate.sh` is the natural home: it is the shipped program whose declared subject is
already this ledger's SIZE, and its default is dry-run.

**What the discharged half cost, recorded because the next author will propose it again.** A BYTE
clause was ruled, built and withdrawn on measurement: rotation is the only sanctioned lever and it
is denominated in ENTRIES; archived entries average 7193 bytes against a live mean of 3758, so
archiving one frees 1.9x the live mean; a byte ceiling admitting the same growth sat within 1.5% of
the entry ceiling and bound first, making the entry clause vacuous; and at all four states where
such a clause approached firing the count of rotatable entries was ZERO. A per-entry cap fails too
— 10 of 27 archived entries exceed 8000 bytes and the largest is 16137.

verify: sh D=$(mktemp -d) || exit 9; trap 'rm -rf "$D"' EXIT; git clone -q --local . "$D/r" 2>/dev/null || exit 9; (git ls-files -z -mo --exclude-standard | tar -cf - --null -T - 2>/dev/null) | (cd "$D/r" && tar -xf - 2>/dev/null); RC="$D/r/core/skills/ai-dlc-update/reconcile"; H="$D/r/.githooks/pre-push"; [ -d "$RC" ] && [ -f "$H" ] || exit 9; n=0; for f in "$RC"/*.sh; do [ -f "$f" ] && n=$((n+1)); done; [ "$n" -ge 2 ] || exit 9; awk '/^step /{s=1;next} s&&/^  bash /{print;s=0}' "$H" > "$D/cmds"; [ -s "$D/cmds" ] || exit 9; P=$( cd "$D/r" && wc -c docs/plans/*.md 2>/dev/null | awk '$2!="total" && $1>m {m=$1; f=$2} END{print f}' ); [ -n "$P" ] && [ -f "$D/r/$P" ] || exit 9; mkl() { mkdir -p "$(dirname "$1")"; { printf '# Push-candidate ledger\n\nPreamble prose that belongs to no entry.\n\n'; awk -v n="$2" 'BEGIN{for(i=1;i<=n;i++)printf "## PC-S900-%04d — an open push candidate\n\nBody text.\n\nverify: theirs_has core/scripts/thing.sh \"MARKER_A\"\n\n---\n\n", i}'; } > "$1"; }; mkl "$D/s/l.md" 10 && mkl "$D/b/l.md" 500 || exit 9; [ "$(grep -c '^## PC-' "$D/b/l.md")" -eq 500 ] && [ "$(grep -c '^## PC-' "$D/s/l.md")" -eq 10 ] || exit 9; C8=0; for f in "$RC"/*.sh; do bash "$f" "$D/s/l.md" >/dev/null 2>&1 || continue; bash "$f" "$D/b/l.md" >/dev/null 2>&1 || { C8=1; break; }; done; [ "$C8" = 1 ] || exit 1; cp "$D/r/$P" "$D/po" || exit 9; awk 'BEGIN{for(i=0;i<4000000;i++)print ""}' >> "$D/r/$P" || exit 9; cp "$D/r/$P" "$D/ps"; C6=0; while IFS= read -r c; do ( cd "$D/r" && eval "$c" ) >/dev/null 2>&1 && continue; cp "$D/po" "$D/r/$P"; ( cd "$D/r" && eval "$c" ) >/dev/null 2>&1 && C6=1; cp "$D/ps" "$D/r/$P"; [ "$C6" = 1 ] && break; done < "$D/cmds"; [ "$C6" = 1 ]

---

## BL-093 — the ledger ceiling bounds one member of a wider unbounded population

`scripts/validate-backlog-size.sh` bounds `docs/backlog.md`. Re-derived at batch 178 by ranking
every tracked file by `wc -c` at `297f7499`: `docs/backlog.md` is **194366 bytes, 10th**, and the
larger files are `CHANGELOG.md` (**3190562 bytes / 764 release headings**), `docs/backlog.archive.md`,
`.ai-dlc-fixture-readsets.tsv` (**tracked, regenerated whole, 1726310 bytes / 26311 lines**), two
archived plans, `scripts/validate-enforcement-map.sh` and two fixture drivers.
`docs/plans/retire-graph-consumer-layer.md` has since moved to `docs/plans/archive/` (333144 bytes)
and is not part of this entry. `docs/context-hardening-notes.md` is **108317 bytes** and is the file
`.claude/rules/resident-context.md` directs every session to append stories to. The only other
ceiling in the repo is A6's `DURABLE_MAX` over `CLAUDE.md` + `.claude/rules/`.

Two of these are DEFENSIBLY unbounded — a CHANGELOG is a history and an archive is an archive —
and saying so in their own headers is the cheaper half of the fix, because an audit that has to
re-derive "is this a queue or a log" each time will keep re-filing this entry. The one that is
neither is `docs/context-hardening-notes.md`: it is a live read target with a standing instruction
to append to it and nothing bounding it.

Decide per file whether it is a QUEUE (bound it) or a LOG (say so, in its own header, so the next
audit stops). The plans corpus is NOT part of this entry — it is `BL-006`'s surviving half.

Held note (batch 178): disposition taken under the batch-177 operator ruling
(`docs/plans/graph-ledger-full-drain.md`, OPERATOR RULINGS THIS BATCH) that
`docs/context-hardening-notes.md` is a LOG, unbounded like `CHANGELOG.md`. All three are LOGs.
`CHANGELOG.md` and `docs/context-hardening-notes.md` carry a bold
`**LOG — unbounded by design; rotation does not apply.**` paragraph above their first `## `
heading; the CHANGELOG's is deliberately NOT a `## [` heading, which `validate-release-version.sh`
keys on. The map's line is emitted by the deriver's write block as a `#` comment, which every map
reader skips; the map was not hand-edited, so the line lands in `.ai-dlc-fixture-readsets.tsv` at
the next `fs_usage` or `sandbox` trace (`--tracer both` never writes the map). The receipt binds the
emitter LINE inside the `{ … } > "$MAP"` block, not a whole-file grep, which a comment satisfies.

verify: sh D=core/scripts/derive-fixture-readsets.sh; for f in "$D" CHANGELOG.md docs/context-hardening-notes.md; do [ -f "$f" ] || exit 9; done; E="$(awk '/^\{$/ {f=1; next} /^\} > "\$MAP"$/ {f=0} f' "$D")"; [ -n "$E" ] || exit 9; grep -q '^  echo "# LOG -- unbounded by design; rotation does not apply' <<<"$E" || exit 1; for f in CHANGELOG.md docs/context-hardening-notes.md; do P="$(awk '/^## / {exit} {print}' "$f")"; grep -q '^\*\*LOG — unbounded by design; rotation does not apply\.\*\*' <<<"$P" || exit 1; done; exit 0
## BL-004 — the nine inner pools are owed, and the hook records them as owed

66 workers sit on top of the outer pool. They cannot be swept with an environment variable —
`enforcement-map-sites` scrubs every ambient `AI_DLC_*` name for I10, and I87 binds any key a
shipped program dereferences — so sweeping them means editing the constants on a throwaway
branch that is never pushed.

The design to use: pin the dispatched set, reset the durations record from one golden copy
before every run, visit cells round-robin, and take a difference as real only where two cells'
readings do not overlap.

Carried over from `docs/plans/pre-push-wall-clock.md`, which is otherwise discharged.

verify: manual

---

## BL-005 — `validator-arm-selection` shard `b` has a ~47.8s solo floor set by three serial units; two routes below it were measured and neither taken

Its shard `b` has a measured floor of ~47.8s solo, set by three serial units: a seeded run at
16s, an attribution sweep at 11s, and a mutant's three parallel full runs at 18s. Going below
it needs either a third directory duplicating the 27s prerequisite, or overlapping the seeded
run with the attribution sweep. Both were measured; neither was taken.

**THIS ENTRY IS NOT ABOUT THE POLE, AND ITS HEADING SAID IT WAS UNTIL `v0.583.0`.** The pre-push
pole is `ledger-reverify` at **628s loaded** — pool 12, full suite under
`AI_DLC_FIXTURE_NO_SKIP=1`, taken as the MAX of three calibrated serial runs in a `file://`
clone of `origin/main` at `83747ef4`: **628s** (wall 743s, load average 50.56 at start), **563s**
(wall 629s, load 9.06), **562s** (wall 627s, load 5.30). Since `v0.583.0` that figure is watched
by `scripts/validate-suite-pole.sh` against the tracked baseline
`docs/suite-pole-baseline.tsv`, which is what `BL-257` built. The **166s / 217s** figures this
entry's heading carried were displaced at **v0.541.0** by `BL-088`, whose own landing paragraph
records the pole falling to `ledger-reverify` in the same change — four releases before
`BL-255` read the heading and found it still asserting them. A session scoping performance work
off this entry optimizes a fixture that is not the pole; shard `b`'s floor is a real and
separate subject, and it is the only subject this entry has.

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
## BL-066 — the `named_absorbed` half landed at v0.387.0; the SIBLING half did not, and the release notes say it did

**TRIAGED AT BATCH 10: FOUR OF THE FIVE CLAIMS ARE ABSORBED, THE SIBLING CLAIM SURVIVES, AND
THIS ENTRY STAYS OPEN ON THAT CLAIM ALONE.** Two verifiers attacked the proposed close
independently, agreed on every measurement, and split on scope; the entry text below decided
it. `34c77736` (`v0.387.0`) genuinely fixed `named_absorbed()` — it removed 3 `tail -1` lines
and 3 `VERSION` reads, `na_v` now occurs **0** times in tracked code (controls in the same
invocation: `na_c` 3, `na_o` 2, `na_h` 2), the three surviving `tail -1` occurrences at `:393`,
`:457` and `:473` all classify as COMMENT against a control returning CODE at `:254-256`, and
driving the real function returns `<newest-sha> <oldest-sha> <n> <how>` with no version at all.
The consumer's installed copy is byte-identical. So the version-into-a-permanent-annotation harm
is closed.

**What survives is the SIBLING paragraph below, and it survives on its own words.** That
paragraph names two mechanisms (`| tail -1`, the `VERSION` read) and a distinct harm: *"its
output is the sha an operator is told to go and read. A fix keyed only on `named_absorbed`
leaves that half emitting the same wrong commit."* The mechanisms are gone; **the harm is not**.
`named_ambiguous()` at `:537-541` still resolves the message-grep to a set and emits ONE commit
— `_c="${_hits%%\n*}"`, now the NEWEST rather than the oldest — with no commit count and no
range, and its second field is the number of ledger ENTRIES sharing the prefix, not the number
of citing commits. Driven against a synthetic upstream where THREE commits cite the prefix, the
row emits `a6b80ae 2`, and `a6b80ae` is the ledger-drain docs commit — precisely the
"cited it while closing the ledger" confusion this entry names. Control in the same invocation:
with a one-entry ledger the function returns empty, so the arm discriminates.

**Two things make this a defect rather than an asymmetry worth noting.** `named_absorbed`'s own
shipped header at `:472` states the remedy standard — *"reports WHAT IT KNOWS — how many commits
name the id, and the two ends of the range — and stops electing one of them"* — and the sibling
did not receive it. And **`v0.387.0`'s CHANGELOG asserts *"Both name joins now report what they
know … and elect none of them"*, which is false as measured.** Nothing guards it:
`core/fixtures/ledger-reverify/run.sh:866-890` carries three `NAMED-UPSTREAM-AMBIGUOUS` arms and
none asserts a commit count or a range (control: a bogus token greps 0 in that file while
`NAMED-UPSTREAM` greps 18).

**THE RECEIPT BELOW IS DEAD AND MUST BE REPLACED, NOT RE-ANCHORED.** It exits 9 because
`sed -n "/^named_absorbed() {/,/^}/p"` truncates at the bare `}"` at `:504`, and repairing the
extraction does not rescue it — the assertion tests `$1 = "0.3.0"` and field 1 is now a short
sha, so a repaired receipt exits 1 against the *correct* fix and can never go green. That is the
trap this entry's own "Why this receipt" paragraph says an earlier draft was rewritten to avoid.
The replacement should assert that the `NAMED-UPSTREAM-AMBIGUOUS` row names ≥2 commits when ≥2
cite the prefix. Filed as evidence under `BL-089`, which this widens.

**`named_absorbed()` joins on the OLDEST commit whose MESSAGE mentions the id, which is not the
commit that absorbed the entry, and the version it reads there is interpolated into a permanent
paste-ready annotation.** `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:402` is
`git log -F --grep="$_id" --format=%H "$THEIRS" | tail -1` — newest-first output, so the last line
is the FIRST commit whose message contains the id. `:427` then reads `VERSION` at that commit, and
`:848` interpolates the result into the row's instruction to the operator:
`**ADOPTED UPSTREAM (v$na_v, verified <date>)**`. That annotation is the form `ledger-rotate.sh`
keys on to archive the entry, so a wrong version here is written into the consumer's ledger by hand
and never re-derived.

**The join key is the defect, not the `tail`.** The comment at `:338-341` defends `tail -1` over
`--reverse | head -1` on SIGPIPE grounds and states the premise in as many words — *"the last line
is the FIRST commit to name the id"*. Naming is not absorbing. The two are not the same question,
and nothing between the grep and the `VERSION` read distinguishes them. This is the
`receipt_absent_subjects` "reads vs mentions" class one level along: there, a receipt path a file
MENTIONS was counted as one it READS; here, a commit message that MENTIONS an id is counted as the
commit that landed it. The SIGPIPE argument is orthogonal and does not block a fix — reading the log
into a variable and taking its first line abandons no pipe.

**Measured against this repo's own history, over the 29 `PC-` ids cited in `e939a92`'s message.**
For each id, `git log -F --grep=<id> --format=%H HEAD | tail -1`, `VERSION` read at that commit,
joined to `docs/reviews/graph-ledger-adjudication-data/final-disposition.tsv` on col2 with the
version parsed out of col3's `ALREADY-FIXED-v<X>`:

- **20 of 29 resolve to `e939a92` itself** and would be annotated with that release's version.
- **9 resolve to older commits.**
- **24 of the 29 carry a literal `ALREADY-FIXED-v<X>` verdict.** Of those, **2 agree** —
  `8dc52be`/`0.247.0` and `1537e4c`/`0.372.0` — and **22 disagree**.
- **A 25th is comparable and a `v`-anchored regex cannot see it.** The remaining five are 2
  `FALSIFIED`, 2 `DUPLICATE-OF` and one `ALREADY-FIXED-93e05d3` — an `ALREADY-FIXED` naming a SHA
  rather than a version. It is a real absorption claim, so it belongs in the comparable set:
  `93e05d3` CHANGES `VERSION` itself, `0.101.0` -> `0.102.0`, so it IS its own release and shipped
  at **`0.102.0`**, while the join reports **`0.373.0`**, resolving to `e939a92`. **So the split is
  25 comparable, 2 agreeing, 23 disagreeing**, and only the four refutation/duplicate rows name no
  absorbing release at all. Control in the same invocation: an impossible id resolves to 0 commits.
- **BOTH SHAPES EXIST IN THIS HISTORY AND ASSUMING EITHER IS AN ERROR.** A fix commit may land
  while `VERSION` still holds the previous number, with the bump arriving later in a separate
  release commit — that is `941021d`, the case the consumer's own `PC-S334` filing is about. Or the
  fix commit may BE the release, bumping `VERSION` in the same commit — that is `93e05d3`. Resolving
  a sha to its shipping release therefore takes the earliest `VERSION`-changing commit **at or
  after** it, inclusive of the commit itself.
- **THE SHA FORM IS THE SHAPE A JOIN SILENTLY MISBUCKETS, AND THIS ENTRY DEMONSTRATED IT TWICE.**
  A first derivation put the row in a bucket labelled "no comparable verdict" — not because it lacks
  one, but because the parser's grammar was `ALREADY-FIXED-v[0-9]` and the row spells its version as
  a commit. A zero over the wrong grammar reads exactly like an absence, and here it read as a row
  with nothing to say while it was in fact the largest single disagreement in the set.
- **3 of the 9 older resolutions are upstream's own documentation commits**, whose diffs are
  docs-only and which merely mention the id: `2bc7aa4` (`docs(plan)`, 1 file),
  `c9a4500` (`docs(reviews)`, 4 files), `40770c3` (`docs(reviews)`, 6 files).
- A fourth, `5b5b95c`, is worse than a docs mention: it is a ledger-drain release touching 23
  `core/` files, and the entry it is attributed to —
  `PC-S303-UNREGISTERED-DRIFT-SCANS-FIVE-OF-TEN-CORE-SUBTREES` — is adjudicated **FALSIFIED**. The
  function would propose an `ADOPTED UPSTREAM` annotation for an entry that was never a defect.

Control in the same invocation: the impossible id `PC-S999-IMPOSSIBLE-NEVER` resolves to **0**
commits while `PC-S300-CYCLE-STATE-RESOLVED-UNREACHABLE-FOR-A-STALLED-TERMINAL-PASS` resolves to
**2**, so the search runs and discriminates.

**This repo's own instruction produced the 20-row case.** `docs/plans/graph-ledger-full-drain.md:49`
directs that *"the id goes in the RELEASE COMMIT MESSAGE, verbatim, for every closed entry"*. That
correction is right for coverage and it is exactly what makes an unqualified message-grep resolve to
the release commit — the id is now guaranteed to appear in a commit whose relationship to the fix is
"cited it while closing the ledger", which the join cannot tell apart from "landed it".

**A SIBLING INSTANCE, SAME IDIOM, SAME FILE.** `named_ambiguous()` (`:433`) runs the same
`| tail -1` at `:453` and reads `VERSION` at `:455`, and its output is the sha an operator is told to
go and read. A fix keyed only on `named_absorbed` leaves that half emitting the same wrong commit.
The prefix-fallback arm inside `named_absorbed` at `:423` is a third site of the same idiom.

**NOT the same defect as `absorbed_at()`.** `absorbed_at()` (`:267`, `VERSION` at `:271`) uses a
content pickaxe (`log -S"$2"`) bounded to `BASE..THEIRS` with `--reverse | head -1`, so it already
joins on a diff rather than on a message; its filed problem is which version blob it reads at the
commit it found. Filed by the consumer as
`PC-S334-ABSORBED-AT-READS-THE-VERSION-BLOB-AT-THE-FIX-COMMIT`. Cross-referenced, not merged — the
two need different fixes and a joint one would satisfy neither join.

**Why this receipt and why it is behavioural.** A substring anchor is unusable: the fix will quote
the `tail -1` wording back inside the comment recording what it replaced, exactly as `:338-341`
already quotes the reasoning it is defending. The receipt instead `sed`-extracts the shipping
`named_absorbed()` body, evals it against a three-commit synthetic upstream in which a `docs(plan)`
commit at `0.2.0` MENTIONS the id and touches no subject, and the `fix:` commit at `0.3.0` absorbs it
— and asserts the returned version is the absorbing one. Its four sanity arms exit 9 (which reverify
reports as STILL-LIVE, the safe direction): the extraction produced a function, the two commits'
`VERSION` blobs genuinely differ, the mentioning commit really mentions the id, and the mentioning
commit does NOT touch the subject while the absorbing commit does. An earlier draft guarded on the
extracted text containing `tail -1`, which would have exited 9 on precisely the fix — a receipt that
cannot go green. Satisfiability demonstrated against a mutant whose two sides were asserted to
differ: shipping returns `0.2.0 <sha> slug` and exits **1**; the same receipt against a copy with
`| tail -1` changed to `| head -1` in that arm returns `0.3.0` and exits **0**.

Cross-references the consumer entry `PC-S334-NAMED-ABSORBED-JOINS-ON-THE-OLDEST-MESSAGE-MENTION`,
filed by the graph consumer session. That id appears in **0** commits of this repo's history
(control in the same invocation: `PC-S303` appears in **8**), so nothing upstream can be read as
having answered it.

verify: sh L=core/skills/ai-dlc-update/reconcile/ledger-reverify.sh; f=$(sed -n "/^named_absorbed() {/,/^}/p" "$L"); case "$f" in *"named_absorbed()"*) : ;; *) exit 9 ;; esac; d=$(mktemp -d); u="$d/u"; mkdir -p "$u/docs"; git init -q "$u"; git -C "$u" config user.email a@b; git -C "$u" config user.name a; printf "0.1.0\n" > "$u/VERSION"; printf "x\n" > "$u/subj"; printf "p\n" > "$u/docs/plan.md"; git -C "$u" add -A; git -C "$u" commit -q -m "chore: seed"; printf "0.2.0\n" > "$u/VERSION"; printf "pp\n" > "$u/docs/plan.md"; git -C "$u" add -A; git -C "$u" commit -q -m "docs(plan): a handoff that MENTIONS PC-S999-PROBE-SLUG and touches no subject"; printf "0.3.0\n" > "$u/VERSION"; printf "fixed\n" > "$u/subj"; git -C "$u" add -A; git -C "$u" commit -q -m "fix: absorb PC-S999-PROBE-SLUG"; o=$(git -C "$u" show HEAD~1:VERSION); n=$(git -C "$u" show HEAD:VERSION); [ "$o" != "$n" ] || { rm -rf "$d"; exit 9; }; case "$(git -C "$u" log -1 --format=%B HEAD~1)" in *PC-S999-PROBE-SLUG*) : ;; *) rm -rf "$d"; exit 9 ;; esac; case "$(git -C "$u" show HEAD~1 --format= --name-only)" in *subj*) rm -rf "$d"; exit 9 ;; esac; case "$(git -C "$u" show HEAD --format= --name-only)" in *subj*) : ;; *) rm -rf "$d"; exit 9 ;; esac; r=$(DIST="$u" THEIRS=HEAD bash -c "$f; prefix_entry_count(){ echo 0; }; named_absorbed PC-S999-PROBE-SLUG"); rm -rf "$d"; [ -n "$r" ] || exit 9; [ "$(printf "%s" "$r" | awk "{print \$1}")" = "0.3.0" ]


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

**Why there is no `sh` receipt, stated rather than worked around.** The two cases a fix must
separate are, on today's signals, the same shape: both are a bold bullet inside a closed entry,
both carry a receipt below them (`susp_hasv`), and the real-entry case does not even carry the
trailing colon (`susp_colon`) that would mark an annotation lead-in. The ONLY thing separating
them in the current parse is the quotation itself — the real entry quotes the annotation form
because it is discussing it, and a genuine lead-in does not quote, it IS one. That is an
accidental signal, not a designed one, and a fix needs a signal the parse does not currently
compute. A receipt asserting both arms would therefore be UNSATISFIABLE against every predicate
available today, and shipping one would be a standard nobody can meet.

The two cases a fix must satisfy simultaneously, so the next session does not have to rederive
them: `core/fixtures/ledger-rotate/run.sh`'s `splitter` seed must be REFUSED, and its `fp-quotes`
seed must NOT be. Both already exist in that fixture and both are already asserted.

Found while remediating `BL-035`, by that fixture, against its own author.

verify: manual

## BL-083 — `verification-discipline.md` prescribes a root marker a consumer tree does not carry

**`verification-discipline.md` prescribes a root marker that does not exist in one of the two
layouts, so a fixture that follows the rule exactly cannot resolve its root on a consumer — and
the fixtures that work do so by the idiom the same rule forbids.** The rule reads *"Resolve the
repo root by walking up for a marker. Never count `..` hops... Walk up for `VERSION`."* Measured:
`scripts/install.sh` into an empty directory produces a tree with **0** `VERSION` files at any
depth, while the distribution root carries one — control in the same invocation, the installed
`tests/fixtures/<name>` directory IS present, so the install ran and the absence is real.

**The correct two-layout resolver already exists in this repo and the rule restates a different
one.** `core/scripts/validate-provenance-block.sh:98` is `ai_dlc_resolve_root()`, which walks up
for `.git` OR `.claude` OR `core/skills/ai-dlc` — a marker set satisfied in BOTH layouts, and
inlined into every validator that needs it with a comment recording why duplication is correct
there. So this is not a missing mechanism; it is a rule that restates one and has drifted from
it, which is the failure `mechanism-design.md` names as *"a rule that RESTATES a mechanism drifts
tighter than the mechanism, invisibly."*

**It was found the way it bites: by a fixture author following the rule.** A new fixture's first
draft walked up for `VERSION`, passed every distribution test, and then failed **all six arms** on
a tree built by `install.sh` with *"no VERSION marker … cannot resolve its own tree"*. It now
walks up for its own home — `<root>/core/fixtures/<name>` or `<root>/tests/fixtures/<name>` — which
is self-anchoring and additionally names the layout it resolved.

**The population is not one file.** **16** of the shipped fixture `run.sh` files test a `/VERSION`
marker (control in the same invocation: **155** carry the token `FIXTURE`, so the grep reaches the
corpus). Most other shipped fixtures resolve by counting three `..` hops — which happens to be
correct in both layouts and is the exact idiom the rule prohibits. So the rule is currently
obeyed by the files that break on a consumer and disobeyed by the files that work, which is the
strongest available evidence that the rule rather than the fixtures is what is wrong.

**Scope note, deliberately narrow.** The 16 is a FLOOR and an approximation: it counts files
testing the literal marker path, and a fixture that resolves correctly by another route may still
appear. The entry's claim is the divergence and the consumer-side zero, both of which are exact;
the 16 is offered as a population size to re-derive, not as a defect count.

**Why the receipt is two-armed.** Two different fixes are legitimate and a one-sided anchor would
go unsatisfiable when the other is taken: `install.sh` could land a root marker in the consumer
layout, or the rule and its followers could move to the marker set the shipped validators already
use. It closes on either, and it drives a real `install.sh` rather than reading the rule's prose,
because text about a program is not the program. It exits 9 — STILL-LIVE, the safe direction — if
the install did not produce a tree, so a broken probe cannot read as a fix.


Held note (batch 178): the rule is corrected and the population claim is refuted, so this entry
CLOSES at the close commit. The section now names `ai_dlc_resolve_root()` at
`core/scripts/validate-provenance-block.sh:138` (the `:98` above is stale) and
`core/fixtures/validator-path-resolution`, states `VERSION` exists only in the distribution, and
does not restate the marker set. Population re-derived at this tip: **32** fixture `run.sh` files
carry `/VERSION"` (control: 216 carry `FIXTURE`) — **19** `.dist-only`, **13** shipping. Every
shipping hit was read: all are seed writes (`>`, `echo`, `printf`, `cp`) except one comment, two
`cat "$DIST/VERSION"` reads of a seeded dist, and one `test -f "$THEIRS_TREE/VERSION"` inside a
seeded receipt string. **0 shipping fixture walkers**; the walker pattern matches 11 lines in the
`.dist-only` set, and an any-case `[ -f "$VAR/VERSION" ]` test matches 0 shipping files against 9
`.dist-only` ones. The
"16 shipped fixtures test a `/VERSION` marker" paragraph above counted seed-writers as walkers. A6
after the edit: 64721/67584. The receipt below replaces the install-driving one, which could only
close by a fix this entry no longer asks for; it is keyed on the SECTION span, bounded at 40
lines. Scored: base 1, fix 0, name added elsewhere in the file 1, name added inside the section
with "Walk up for `VERSION`" kept 1, section unbounded to EOF 9, heading renamed 9.

verify: sh f=.claude/rules/verification-discipline.md; [ -f "$f" ] || exit 9; s="$(awk '/^## Resolve the repo root/ { f = 1; print; next } f && /^## / { exit } f' "$f")"; [ -n "$s" ] || exit 9; [ "$(printf '%s\n' "$s" | wc -l)" -lt 40 ] || exit 9; grep -qF 'ai_dlc_resolve_root' <<<"$s" || exit 1; grep -qF 'Walk up for `VERSION`' <<<"$s" && exit 1; exit 0


## BL-103 — an `ai-dlc-*.sh` hook the settings template cannot register withholds `--finish` forever

**`--finish` gates on `WORKLIST settings-merge`, and that row's own prescribed remedy does not
always clear it.** `settings-merge.sh` re-applies the TEMPLATE's owned hook block; it cannot
register a hook the template does not carry. So a consumer holding an `ai-dlc-*.sh` hook that
upstream has retired — or one whose registration the operator declined — gets
`validate-hook-registration.sh` rc 1 on every run, and the finisher withholds with no reachable
exit short of deleting the hook by hand.

Measured against a consumer built from the shipped template with the real validator: clean
consumer rc 0 gives `RESOLVED restamp` and a cleared marker; one unregistered `ai-dlc-*.sh` on
disk gives rc 1, `WORKLIST settings-merge`, `DECISION restamp-withheld` and a present marker;
running the row's own remedy left the validator still at rc 1 and the state unchanged.

Reachable because `apply.sh` emits `DECISION deletion` and never removes a consumer file, so a
hook retired upstream persists across every later pull.

**The population is EMPTY today and that is stated rather than assumed**: the reference consumer
carries 19 hooks and registers 19, validator rc 0, and `git log -p templates/settings.json.template`
shows zero genuinely retired hook names — the one candidate on a `-` line is still in the current
template, a moved line. A loaded gun, not live fire.

Tiered **DEFECT**. It wedges a consumer's push with no in-band exit, but nothing reaches the
state today.

Found by an adversarial pass on `v0.426.0`. Not a `PC-` candidate, so it ranks below the
PC-backed set.

verify: sh s=core/skills/ai-dlc-update/reconcile/settings-merge.sh; a=core/skills/ai-dlc-update/reconcile/apply.sh; [ -f "$s" ] && [ -f "$a" ] || exit 9; grep -q 'say WORKLIST settings-merge' "$a" || exit 9; grep -q 'worklist_n' "$a" || exit 9; code=$(sed 's/#.*//' "$s"); grep -q 'jq' <<<"$code" || exit 9; grep -qE '(echo|printf|say)[^#]*(retired hook|not carried by the template|cannot be registered)' <<<"$code" && exit 0; exit 1

---

## BL-119 — a `retire` verdict on an EXTENSION reaches no actor, because no step exists to reach

**Uncovered while fixing `BL-118`, and it is the same class one subject over — but not the same
defect, and the difference is the whole finding.** `apply.sh:731-741` suppresses the
`WORKLIST extension-reread` row on any recorded verdict, exactly as the override loop did. That
suppression is CORRECT: the row's obligation is *"re-read this entry against the new core text and
record a verdict"*, and any recorded verdict discharges it. The reading has been done.

**What is missing is the other half.** For an override, `still-additive` means keep and the other
two authorize a remedy the script emits. For an extension, `retire` and `contradicts-core` are
recordable, are honest answers, and authorize nothing — **there is no extension remedy emitter in
the tree at all.** Derived over `core/`, with the override path as the control in the same
invocation:

```
say (NOTE|WORKLIST|HARD…) <kind>  across apply.sh   -> 8 distinct kinds, none of them a retire
                                                       or repair for an extension
grep -rn 'extension-retire' core/                   -> 0
grep -c  'stamp retire' …/apply.sh                  -> 4    # control: the OVERRIDE path has one
```

`layer-drift.sh:1526` does tell a consumer to retire an extension that merely duplicates core, but
that is the `EXTENSION-TITLE-MATCHES-CORE` row and a different subject; nothing carries a
`retire` recorded against `EXTENSION-HOOK-DRIFT`. So a consumer that reads the entry, concludes it
should go, and records that honestly is left with a decision nobody is told to act on — the
outcome `BL-118` names, reached by a route `BL-118`'s fix does not touch.

Tiered **DEFECT**, and the consequence is silence rather than a wrong prescription: no consumer
has been observed hitting it, unlike `PC-S307`, which was filed off a live pull. Not filed
upstream — it was found here.

The receipt is the same DIFFERENTIAL the `apply-worklist-rows` fixture uses on the override side,
and its first cut was wrong in a way worth recording: comparing the two runs' full output scored
**0** on the unfixed tree, because the NOTE interpolates the verdict name and the two messages
therefore differ by construction. Keyed on the row SEVERITY and KIND instead it reads 1 here, and
0 against a mutant that emits any distinct row for a non-keep verdict. Exit 9 if the loop cannot
be located or the keep run emits nothing.

verify: sh set -e; a=core/skills/ai-dlc-update/reconcile/apply.sh; [ -f "$a" ] || exit 9; t=$(mktemp -d); sed -n '/^while IFS="$TAB_CH" read -r ext detail; do$/,/^EOF$/p' "$a" > "$t/l.sh"; [ -s "$t/l.sh" ] || exit 9; { echo 'TAB_CH="$(printf "\t")"'; echo 'say(){ printf "%s %s\n" "$1" "$2"; }'; echo 'ADJ_ROW_TOKEN=adjudicated'; echo 'ADJ_KEEP_VERDICT=still-additive'; echo 'LD_HOOK="$(printf "extensions/e.md\t%s" "$D")"'; echo '. "$T/l.sh"'; } > "$t/d.sh"; r=$(T="$t" D="adjudicated=retire :: p" bash "$t/d.sh" 2>&1) || exit 9; k=$(T="$t" D="adjudicated=still-additive :: p" bash "$t/d.sh" 2>&1) || exit 9; rm -rf "$t"; [ -n "$k" ] || exit 9; [ "$r" = "$k" ] && exit 1; exit 0

## BL-129 — a change to an adjudication predicate has no mechanism that can see what it RECLASSIFIES

**Every fixture seed for `validate-adversarial-convergence.sh` is hand-written, and written by
whoever is changing the predicate. So the suite cannot answer the one question a predicate change
raises: does this reclassify artifacts that were VALID under the predicate it replaces?** A green
fixture, a green mutant battery and a green gate are all consistent with a change that turns a
consumer's history non-conforming, because every input was authored against the new rule.

**Measured, not hypothetical.** `v0.442.0` shipped with `check-24` at 111 assertions, seven mutants
killed and the full gate green. Driven over the reference consumer's real pass series it turned
**33 from PASS to FAIL, 0 the other way**, three of them in a sprint that consumer had PAUSED. The
defect was found by running the shipped validator over a tree outside this repo, at the point the
operator said they were about to pull — not by anything in the gate. `v0.443.0` corrected it.

**THE PROMPT-SIDE REMEDY IS ALREADY KNOWN AND IS NOT ENOUGH.** "Run the differential against the
consumer before cutting the release" is correct and is being followed, but its only carrier is a
session's recollection, which `resident-context.md` says is not a carrier. It also lives on ONE
side of the boundary: `v0.442.0` reached a consumer precisely because a single party was looking.

**THE FRAMING ABOVE IS WRONG IN A WAY THAT MATTERS, AND THIS PARAGRAPH IS THE CORRECTION.** The
thing that caught `v0.442.0` was a DIFFERENTIAL, not a characterization: two predicates, old and
new, over whatever tree exists at the time. Nothing is frozen, so there is no golden verdict and no
moment at which today's bug becomes the reference — objection 1 below does not apply to it, and
neither does objection 2, because a differential enumerates the same set TWICE IN ONE RUN and a
wrong population definition cancels. Measured: the two parties' grammars disagreed 105 against 94
and the CHANGED count was 33 under both, then 0 under both. So the instrument is not missing.

**WHAT IS MISSING IS AN INPUT, AND THE REASON IS NOT ONLY THAT NO CONSUMER TREE IS ON THIS SIDE.**
Run the same differential over THIS REPO'S OWN fixture seeds and it reports **2 changed cells
against the consumer's 33** — and the two are the tell. Derived by driving the `0.441.0` and
`0.442.0` validators over the seed as it stood AT `v0.442.0`:

    ceiling-at-limit          0.441.0=1 -> 0.442.0=0     the INTENDED effect
    ceiling-refuses-at-limit  0.441.0=0 -> 0.442.0=1     THIS WAS THE REGRESSION

**The regression DID appear, as one row, and it was indistinguishable from the intended change
because the same session authored both the predicate and the case declaring that row correct.**
`ceiling-refuses-at-limit` was written to expect exit 1. The fixture scored it green. A differential
on this side does not fail for want of volume; it fails because its expectations are authored by the
hand being checked — the defect `.claude/rules/fixture-mutants.md` names as keeping the fixture
author different from the arm's.

**AND THE GENERAL FORM IS NEITHER AUTHORSHIP NOR VOLUME: AN INPUT SET THAT AGREES BY CONSTRUCTION
CANNOT DISCRIMINATE.** The two rows above agree because one hand wrote the predicate and the case.
A consumer artifact written AFTER a predicate ships agrees for a different reason and is equally
useless. So the discriminating population at any future pull is the subset PREDATING the predicate
under test, never the total — and quoting a total is how a vacuous run reads as a clean one.

**Derived, with a control, against the consumer at `0.443.0`:** of 94 series, **75 carry a
derivable `invoked_at`**, and **all 75 predate the `v0.442.0` merge — 0 do not**. Cut taken as a
full UTC instant (`2026-08-30T02:54:46Z`), not a date. Control: the same query at an
impossible-future cut returns 75, matching the derivable count.

**AN EARLIER REVISION OF THIS ENTRY PUBLISHED "3 POST-CUT" AND IT WAS WRONG, BY THE SAME CLASS OF
BUG THE ENTRY IS ABOUT.** The cut was written as the DATE `2026-08-29` and compared with `<`, so a
series whose newest pass fell ON that date was not less-than and dropped into the post bucket. All
three were `s307` series timestamped `2026-08-29`, i.e. genuinely pre-cut. **A date-only compare
mis-buckets exactly the same-day window the question is about**, and the artifacts carry `Z` while
`git show -s --format=%cI` returns an offset, so the two are not comparable as strings at all. Both
parties hit this independently; one of them got the right answer from the wrong method on the first
run, which is why it survived to be published here.

Two things follow, and both are limits on the metric rather than on the corpus:

- **19 of 94 series carry no derivable `invoked_at` at all**, so the discriminating-subset query
  cannot classify a fifth of the corpus and silently drops it. A figure taken from this metric is a
  FLOOR, and reporting it without that sentence repeats the defect one level up. **This is the
  finding to keep** — it holds at 19-of-94 and at the peer's 27-of-105, and it does not depend on
  which cut either party chose.
- **0 post-cut is the EXPECTED answer today and is not reassuring.** That consumer's pipeline has
  been paused throughout, so nothing could have been authored under the new predicate yet. The
  decay has not begun because nothing has RUN; it begins the moment the sprint resumes. Do not read
  today's total-equals-discriminating as a standing property — it is an artifact of a stopped
  pipeline, and a later run reporting a small pre-cut subset cannot discriminate at all.

**So the entry's subject is a BOUNDARY, not a missing tool**, and `consumer-boundary.md` already
owns it: the only inputs that can discriminate are artifacts THIS SIDE DID NOT WRITE. Do not spend
effort building a corpus to recover a property a differential has for free, and do not assume a
frozen input set fixes it — a set harvested here and blessed here reproduces the same defect one
layer down.

**AND THE INPUTS ARE ONLY HALF OF IT: A SINGLE DERIVATION OVER PERFECT INPUTS IS STILL WORTHLESS.**
Whoever scopes this will be tempted to read the paragraph above as "obtain the right artifacts, then
measure". That is not what happened. Across this episode BOTH parties wrote a wrong query on the
FIRST attempt, over the same real artifacts, every time:

- a series-prefix grammar that stripped the `-pass` stem — returned a clean `12 of 12 unchanged`,
  which reads as a refutation;
- a `find -name` predicate matching the BASENAME — returned a confident `32 over 75`, and the
  surviving exclusion was CORRECT BY LUCK;
- a cut written as a DATE and compared with `<` — mis-bucketed the same-day window that was the
  entire question, and published `3 post-cut` against a true `0`;
- a string compare of a `Z` timestamp against a `-04:00` offset — which returned the RIGHT answer
  for the WRONG reason, and would have shipped undetected on its own.

**Not one of those was caught by the tree, by a control, or by the party that wrote it.** Every one
was caught by a SECOND derivation, by a different hand, disagreeing out loud and then reconciling.
`fixture-mutants.md` states this for fixtures — *"keep the fixture's author different from the
arm's; an arm and a battery written by the same hand cannot disagree"* — and this entry is the
same rule for MEASUREMENTS. A mechanism that hands one session the right artifacts and one query
has reproduced the defect it was built to prevent.

**Consequence for scoping: whatever is built here must produce a number a SECOND party can
independently re-derive and compare**, and its output must carry the population definition it used,
because that definition is where all four errors above lived — never in the arithmetic.

**Candidate mechanism, NOT chosen and possibly not viable — a characterization corpus.** Freeze a
set of real-shaped pass series in the tree with their adjudicated verdicts, and fail the push when a
predicate change flips one without a declared reason. Read the paragraphs above FIRST; these three
objections are why it is recorded as a candidate rather than a plan:

- **A frozen verdict encodes today's behaviour as correct, and the counterfactual is exact.** Put
  by the peer session that measured the 33: *had `v0.442.0`'s arm B shipped a week earlier and the
  corpus been cut after it, the 33 would have frozen as CONFORMING and `v0.443.0` would have read
  as the regression.* A corpus can only ever encode what the predicate said when it was frozen,
  which is the thing under test. **This is the objection to answer first, and neither side has an
  answer.** A characterization corpus is not an oracle and must not be scoped as one.
- **`consumer-boundary.md` says no gate reaches the consumer's tree**, so the corpus must be
  committed here — and a committed copy of another repo's artifacts goes stale silently, which is
  the class this repo already has scars from.
- **AND THAT CORPUS WAS NEVER STABLE TO BEGIN WITH, which is worse than going stale.** The only
  tree holding real series is a LIVE sprint working directory: the population changes every
  sprint, artifacts are archived into `*-cycle-1/` directories mid-cycle, and the population
  DEFINITION was derived wrongly twice in one day by two parties before the two answers agreed —
  once as a silent under-count, once as an over-wide set including repair and resolution records
  that are not pass series at all. A harvest inherits all of that.
- **A declared-reason escape hatch is an opt-out**, and `CLAUDE.md` holds that an instruction
  shipping its own opt-out is not an instruction. Whether the declaration can be made costly
  enough to bind is the open design question.

**Scope note: this is NOT specific to the adversarial validator.** Ask, before scoping, which other
shipped predicates adjudicate persisted artifacts a consumer already holds — that population is the
entry's real subject and it has not been derived.

Held note (batch 178): PREMISE CORRECTION, and the entry is re-scoped. The differential this
entry calls "not missing" SHIPPED: `core/skills/ai-dlc-update/reconcile/predicate-differential.sh`
landed in v0.444.0 (`0ca1d0e9`) and is wired as update `SKILL.md` step 3g, driven by the site
manifest `reconcile/predicate-sites.md`. That manifest declares two sites today
(`validate-adversarial-convergence.sh`, `validate-provenance-block.sh`). What remains is (1) three
shipped validators that adjudicate a consumer's STORED artifacts and are not declared there —
`core/scripts/validate-gate-adjudication.sh` (named in the manifest's prose at `:53`, but given no
site block), `core/scripts/validate-snapshot-conservation.sh`, and
`core/scripts/validate-suppression-lifetime.sh`; and (2) the population field the "consequence for
scoping" paragraph above asks for: a site's output does not carry the population definition it used
or how many artifacts it could not classify, so a second party cannot re-derive the figure. The
characterization-corpus candidate is unchanged and still not chosen. No code in this batch.

verify: unscoped — this entry records a gap and names a candidate, not a receipt. Do not close it
on a green `check-24` run or a green suite; that green is exactly what failed to see the defect.

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

verify: unscoped — this entry records a gap, not a receipt. Do not close it on a green
`layer-drift.sh` run; that green is the defect.

## BL-127 — a fixture is skipped by the read-set map on exactly the change that breaks it

**`.ai-dlc-fixture-readsets.tsv` decides which fixtures a push runs, and a MAPPED fixture whose row
omits a file its `run.sh` actually opens is skipped on the one change most likely to break it.** The
fail-closed arm in `.githooks/pre-push` rescues only UNMAPPED fixtures — a mapped row with a hole
is trusted, so the hole is silent.

**Measured on the working tree, filtered to files that really exist under `core/hooks/`: 20
(fixture, hook) pairs across 15 distinct fixtures.** Control in the same derivation: the map does
carry hook paths — `ai-dlc-pause.sh` appears in 35 rows — so a zero would have meant the grammar,
not the corpus.

The instance that motivated this entry: **`pause-hook-origin` parses `ai-dlc-continue.sh` at four
sites and does not list it.** That fixture owns the `cat > "$LOG_FILE" <<'EOF'` log legend, 2860
bytes required byte-identical across FIVE hooks, and it is the only thing guarding that invariant.
A push touching only `ai-dlc-continue.sh` does not select it. `v0.441.0` edited that hook and
passed only because the release was gated with `AI_DLC_FIXTURE_NO_SKIP=1` by hand.

**THE FALSE-POSITIVE SET IS NOT MEASURED, AND MEASURING IT IS THE FIRST THING THIS ENTRY OWES.**
"Parses" here means the `run.sh` mentions the basename, and at least one hit is known to be
path-as-data rather than a read — `layer-readopt-gate` passes `hooks/ai-dlc-continue.sh` as an
ARGUMENT to the override-registration script and never opens it. So 20 is a CEILING on the real
population, not a count of defects, and this entry must not be closed on a fix whose FP set was
never taken. The discriminator is whether the path is OPENED, which a mention-grep cannot see.

**Do NOT fix this by hand-editing 20 rows.** The map is trace-derived; hand-patching it puts a
second, drifting declaration beside the derivation and the next regeneration silently reverts it.
The fix belongs at the point the map is GENERATED, or in an arm that fails the push when a mapped
fixture's row omits a `core/hooks/` path its `run.sh` opens — which is the same shape as the
existing bidirectional joins and is why the receipt below keys on an arm existing rather than on
the count reaching zero.

**A count-reaching-zero receipt would be unattainable and is deliberately not used.** Until the FP
set is enumerated, some of the 20 are legitimate, so "the gap is 0" is a criterion that can never
go green — the documented failure mode for acceptance criteria in this repo.

Discovered while shipping `v0.441.0`, which addressed the reference consumer's
`PC-S307-CONTINUE-HOOK-CANNOT-DISTINGUISH-A-DIRECTED-SESSION-FROM-AN-UNATTENDED-ONE`. Not filed by
that consumer and carries no `PC-` id of its own; it is an ai-dlc-internal discovery and ranks
below any PC-backed entry under the provenance-first rule.

**Tiered DEFECT.** It does not corrupt anything; it removes a guard silently, and the symptom of a
missing guard is a green push.

Held note (batch 178): the false-positive set this entry owes is now MEASURED, and it does NOT
support re-tiering to NOTE. Re-derived at this tip: **25** (mapped fixture, `core/hooks/` basename)
pairs where `run.sh` names the hook and the fixture's rows omit `core/hooks/<name>` (control in the
same derivation: 61 pairs where the row DOES carry it). **19** are comment-only mentions (an
earlier count read 18). The **6** non-comment ones were inspected by hand. Five do not open the
core hook: `layer-readopt-gate` passes `hooks/ai-dlc-continue.sh` as an argument,
`core-write-guard` puts a consumer path in tool-call JSON, `upstream-routing` truncates a stub in
its own consumer tree, `settings-merge-unparseable-template` greps a template for the name, and
`gate-repair-record` quotes it in prose. **The sixth is a live instance:**
`postcompact-rulebook-recovery` resolves `core/hooks/ai-dlc-postcompact.sh` in `seed.sh:46` and
executes it at `run.sh:1762`. Its rows carry four other hooks and not that one. They were last
derived on 2026-09-15; the arm that reads that hook landed on 2026-09-22 (0.620.0), and none of the
22 map commits since then changed a `postcompact-rulebook-recovery` row (the largest re-derived 11
fixtures, so each was a `--list` partial, not a full re-trace). A push
touching only `ai-dlc-postcompact.sh` skips the one fixture guarding the defect 0.620.0 fixed. The
motivating instance is closed: `pause-hook-origin`'s rows now carry `core/hooks/ai-dlc-continue.sh`.
Two corrections to the method above: a `run.sh`-only mention grep misses reads resolved in a
sibling `seed.sh` (this instance names the hook in `run.sh` only in messages), and the remedy is a
re-trace of `postcompact-rulebook-recovery`, not a hand-edited row. Tier stays **DEFECT**.

The receipt is STRUCTURAL: it exits 1 while no arm in `scripts/validate-enforcement-map.sh` binds a
fixture's read-set row to the `core/hooks/` paths its `run.sh` resolves, 0 once one does, and 9 if
the map or the read-set file cannot be located, so a relocated map reports a moved precondition
rather than a false close.

verify: sh m=scripts/validate-enforcement-map.sh; r=.ai-dlc-fixture-readsets.tsv; [ -f "$m" ] || exit 9; [ -f "$r" ] || exit 9; grep -q ai-dlc-pause.sh "$r" || exit 9; h=$(grep -cE "^# --- I[0-9]+[a-z]?:" "$m"); [ "${h:-0}" -ge 10 ] || exit 9; grep -qiE "^# --- I[0-9]+[a-z]?:.*(read-set|readset)" "$m" && exit 0; exit 1

## BL-132 — the safe-stop acquittal answers a question about BEHAVIOUR with a test on ancestry

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

verify: sh g=core/skills/ai-dlc-update/reconcile/self-update-gate.sh; [ -f "$g" ] || exit 9; grep -q "advise_safe_stop" "$g" || exit 9; grep -vE "^[[:space:]]*#" "$g" | grep -qE "(show|archive|worktree)[^|]*preclassify" && exit 0; exit 1

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
consumer installs" but "does the commit change something THIS id's subject depends on", and a
per-id subject path is a datum nothing currently records. Scope that before building either
version. A weaker but constructible half: a release commit citing an id it does not FIX needs a
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

verify: sh set -e; r="$PWD"; id='PC-S295-RETRO-PARALLEL-OPEN-COUNT-METHOD'; n=0; c_core=0; for c in $(git -C "$r" log --format=%H -F --grep="$id" origin/main); do n=$((n+1)); git -C "$r" show --name-only --format='' "$c" | grep -q '^core/' && c_core=$((c_core+1)); done; [ "$n" -gt 0 ] || exit 9; [ "$c_core" -eq 0 ] || exit 0; w=$(mktemp -d); mkdir -p "$w/c/_bmad-output/ai-dlc-update" "$w/c/.claude"; printf '%s\n' '# l' '' "## $id — probe" '' 'Body.' '' 'verify: sh cd "$CONSUMER" && grep -q zzz-never-present README.md' > "$w/c/_bmad-output/ai-dlc-update/push-candidate-ledger.md"; printf 'version: 0.471.0\ncommit: 31b51d48\nskill_version: 0.471.0\nskill_commit: 31b51d48\n' > "$w/c/.claude/.ai-dlc-version"; h="$(git -C "$r" rev-parse HEAD)"; o="$(cd "$w/c" && bash "$r/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh" "$r" 31b51d48 "$w/c" "$h" 2>/dev/null)"; grep -q "$id" <<<"$o" || exit 9; grep -qE "^NAMED-UPSTREAM[[:space:]]+$id" <<<"$o" && exit 1; exit 0



## BL-159 — four handoff-completion defects adjacent to `BL-158`, found by the batch-49 hands and deliberately not fixed there

**PARTIAL IN v0.668.0.** Claim 3 FIXED: auto-handoff step 5 in `_gate-procedures.md` now runs
`rm -f _bmad-output/.handoff-in-progress` beside the pause-flag touch, spelled as `handoff.md` step 5
spells it; `handoff-resume-guard` pins it with a span arm keyed on the step-5 line, self-probed both
ways. Claim 2 DEAD-PREMISE: the consumer tracks the marker 0 times against 5381 tracked paths under
`_bmad-output/`, and `git check-ignore` exits 0 on it. Claims 1 and 4 SURVIVE: `ai-dlc-continue.sh`
still has no working-tree test beside its `PUSH_OK=` lines, and `HANDOFF_ON_DISK`'s only reader sits
inside the transcript-present block. The receipt keys on claim 1 and stays.

Held note (batch 178): claim 4 fixed on this branch. Check 0 in `core/hooks/ai-dlc-continue.sh` now
enters on `HANDOFF_VOCAB_OK` AND (a readable transcript OR `HANDOFF_ON_DISK` OR the sticky
`.handoff-guard-armed` record). With no transcript the resume arm reads 1 = unknown, the In-Flight
arm keeps its existing `-f "$TRANSCRIPT"` fail-open, the block row carries `[no transcript: …]`,
and the completion stamp is not written. `handoff-completion-assertion` arms (nt0)-(nt5) pin the
entry condition, the resume-unknown line, the stamp decision and the sticky entry; mutants m31
(transcript gate restored), m32 (resume parsed from the unread transcript), m33 (stamp without a
transcript) and m34 (sticky not an entry condition) each die on their arm. Claim 1 stays open and
the receipt below still keys on it; claim 4's receipt is the fixture, not this line.

Distribution-internal, no `PC-` id; ranks below any PC-backed entry. Filed together because they
share one subject and one release would otherwise have widened past its scope. NOTE tier for each
until one is measured to have moved a verdict on the consumer.

1. **`PUSH_OK` counts COMMITS, so a skipped step 2 reads `ahead 0` and passes.**
   `core/hooks/ai-dlc-continue.sh`'s push arm reads `git rev-list --count '@{u}..HEAD'`; an
   uncommitted tree is zero commits ahead. The consumer at batch 49 read `ahead 0` with 7 dirty
   files. `handoff.md:64-65` names the trap in prose. A working-tree test beside the ref test is
   the shape; its false-positive set on a consumer whose `_bmad-output/` is deliberately dirty
   mid-sprint has not been measured, which is why it is filed and not shipped.
2. **The entry marker is TRACKED in the consumer although the schema declares it ignored.**
   `core/schemas/pipeline-state-paths.json` marks `_bmad-output/.handoff-in-progress` transient
   with an `ignore` pattern; on the consumer `git ls-files` returns it and `git check-ignore` exits
   1. Two of the schema's 14 transient patterns are missing from the consumer's `.gitignore`
   (control: 12 present). `core/scripts/sync-transient-ignore.sh` is the producer; whether it was
   never run there or predates the two entries is a consumer-side question.
3. **The auto-handoff twin never clears the marker.** `_gate-procedures.md`'s auto-handoff step 5
   creates the pause flag and omits `rm -f _bmad-output/.handoff-in-progress` (control: it names
   `pipeline-paused.flag` once). Today that is inert — an auto-handoff reads no `handoff.md`, so
   no marker exists — and becomes a wedge only if a marker from an interrupted manual handoff
   survives into an auto-handoff, which `BL-158`'s marker arm would then block on correctly.
4. **Check 0's on-disk trigger sits behind a readable-transcript test.** `ai-dlc-continue.sh:288`
   requires `$TRANSCRIPT` to exist before any arm runs, including the `HANDOFF_ON_DISK` path built
   for the case the transcript cannot see. A Stop with no transcript path skips the guard.

verify: sh h=core/hooks/ai-dlc-continue.sh; [ -f "$h" ] || exit 9; grep -q 'PUSH_OK=' "$h" || exit 9; grep -qE 'git -C "\$PROJECT_DIR" (status --porcelain|diff --quiet)' "$h" && exit 0; exit 1


## BL-195 — Check 2's suppression-lifetime arm reads a verdict the CURRENT gate has not yet written, and all four candidate remedies are refuted by measurement

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

## BL-265 — the fork budget's A4 stale-high arm had become unreachable at its own committed budget, and the mutant that should have said so was wired to a derived value

**`core/fixtures/validator-fork-budget/run.sh`'s `judge` evaluates A1 floor before A4
stale-high.** A1 was a hardcoded `[ "$t" -le 5000 ]`, sized when the validator forked 8225. A4
fires only when `t*10 < b*7`. So A4's window is `5000 < t < 0.7b`, which is EMPTY for every
budget at or below 7143. Measured across the budgets this file has actually carried: at
`FORK_BUDGET=8225` (0.583.0) the window was 5001..5756; at `6431` (0.587.0) there was **none**.
A4 — whose own message reads *"a ceiling nothing can reach is a check that cannot fire, and it
reads exactly like one that passed"* — had become exactly that, one release before anyone looked.

**`m3` could not see it, and the reason is the mutant's wiring rather than its predicate.** It
drives `judge` with `budget = T1 * 2`, where the window is non-empty under any floor, so it
stayed green through the closure. The comment above it explains that mutants are wired to `$T1`
rather than `$BUDGET` deliberately — measured, because entangling them with the committed budget
made m5 and m6 fire on the ceiling arm. That reasoning is right for m2–m6 and it is precisely
what left no arm watching the committed budget's own reachability.

**Fixed in this release, both halves.** A1 is now `40%` of `FORK_BUDGET`, so the two bounds move
together; `0.4b < 0.7b` for every positive budget, so A4 has a window at every budget this can
carry. The floor still refuses every input it exists to refuse — measured in one invocation, the
three real broken-tracer cases read **0** (a subject that forks nothing), **0** (the `PS4` marker
neutered, where the profiler's own self-probe refuses first) and **1** (the validator truncated at
line 400, the case A1's header names), against a control of **4767** for the live reading, which
must and does pass. And `m8` asserts A4's reachability at the LIVE budget by constructing the
midpoint of its window — the one mutant that must key on `$BUDGET`. Scored against the old
constant floor it reports the FAIL at `b=6431` and `b=4773` and passes at `b=8225`, which is the
closure it would have caught.

**The trigger was a correct change reading as a broken one.** Taking I59 and I60 from 1724 forks
to 66 put the true reading at 4767, under the constant, and the fixture reported
`BROKEN ... a broken tracer, an unmatched marker or a validator that exited early` with m2, m3, m5
and m6 all going off on A1 instead of their own arms — five failures from one improvement.

**What is owed, and why this entry survives the fix.** The floor is now proportional but the
FRACTIONS are still two literals (`4/10`, `7/10`) in one `judge`, and nothing joins them to the
quantity they are about. A future ratchet that takes the budget far enough down makes `0.4b` a
number a genuinely broken tracer could exceed — the tracer's failure modes read near zero today,
but that is a property of the profiler's current shape, not a bound. The durable form derives the
floor from what a BROKEN subject actually measures rather than from a fraction of the ceiling.

**Tiered DEFECT.** No guard was removed and nothing shipped wrong; what it cost was one arm that
could not fire for a release, and a correct change that had to be diagnosed before it could land.

The receipt keys on the two EMITTING lines — the floor's own `if` test and the `kill_j` call
that drives m8 — never on the file merely containing the fraction or the mutant's name. Its
first form did the latter and was satisfied by a three-line file of pure comments carrying no
executable floor at all; scored again on the emission sites it reads 0 on the real file, 1 on
that prose file and 1 at the parent commit.

**Re-keyed at batch 176.** That receipt scored the two halves that shipped and exited 0 while the
owed half — the literal fractions — stood, so it proposed closing an entry whose own text keeps it
open. It now requires an A1 floor test and m8 to be present AND the literal `4 / 10` floor to be
gone: 1 on today's tree, 0 once the floor is derived from what a broken subject measures, and 1 on a
regression that deletes the floor outright.

verify: sh f=core/fixtures/validator-fork-budget/run.sh; [ -f "$f" ] || exit 9; grep -q 'A4 stale-high' "$f" || exit 9; grep -qE '^[[:blank:]]*kill_j "m8 A4-reachable' "$f" || exit 1; grep -qE '^[[:blank:]]*if \[ "\$t" -le ' "$f" || exit 1; grep -qE '^[[:blank:]]*if \[ "\$t" -le "\$\(\(b \* 4 / 10\)\)" \]; then' "$f" && exit 1; exit 0


## BL-278 — the join between an entry's receipt and the fixture that covers the same subject has no home a consumer can run

**DEFECT.** Found at batch 134, when the arm that would have carried this join was reverted out
of a shipping fixture by the pre-push dead-doc-ref phase.

**THE JOIN IS REAL AND NOTHING ASSERTS IT.** A backlog entry's `verify: sh` receipt and the
fixture arms covering the same subject divide the work between them: the receipt establishes
that the fix is present, and the arms establish what the receipt cannot express. At batch 134
that division was measured rather than assumed — BL-040's receipt is blind to a mutant deleting
only the Check 12 writer half, and blind to a comment or a bare mention replacing the comparand,
so three of the six seeded shapes are fixture-owned. **The division is currently stated in a
comment**, and a comment goes stale in silence: the next hand to widen the receipt reads the arms
as redundant and deletes one.

**WHY IT HAS NO HOME TODAY.** The join's two sides live on opposite sides of the consumer
boundary. The receipt is a line in `docs/backlog.md`, which `install.sh` does not ship; the arms
live in `core/fixtures/gate-verdict-grep-shape/`, which does. Derived at this tip, both sides in
the same invocation: `grep -rlF 'docs/backlog.md' core/fixtures/` returns **4** fixtures —
`backlog-ledger`, `backlog-receipt-binding`, `backlog-rotate-fence-guard`, `backlog-size-ceiling`
— and **4 of 4** carry a `.dist-only` marker, against **0** shipping ones. So the tree's existing
answer to this class is unanimous and the arm that broke it was the anomaly.
`scripts/validate-no-dead-doc-refs.sh` enforces exactly that, and the class it names is not
cosmetic: a shipping fixture whose corpus is absent on a consumer STANDS DOWN there, and a unit
that cannot fail scores as a pass in that consumer's own suite verdict.

**THE OBVIOUS REPAIR IS THE ONE TO REFUSE.** Hardcoding the receipt into the fixture makes the
arm runnable on a consumer and creates a second definition of the receipt — which is the drift
this entry exists to prevent, one level down. The receipt must be DERIVED from the entry or not
scored at all.

**What is owed is a `.dist-only` home beside the other backlog units.**
`core/fixtures/backlog-receipt-binding/` already reads `docs/backlog.md` (14 sites) and already
drives receipts over seeded ledgers, and its `.dist-only` marker states this exact reasoning.
Whether the join belongs as arms there, or in a new `.dist-only` fixture, is the scoping question
— `.claude/rules/fixture-ship-decl.md` governs either way, and a NEW fixture directory also owes
a read-set row the operator must derive with root.

Discharges nothing upstream; this is distribution-internal and ranks below any PC-backed entry.

Held note (batch 178): the join now lives as arms `rj-*` in `core/fixtures/backlog-receipt-binding`
(`.dist-only`). BL-040's receipt is DERIVED from `docs/backlog.archive.md` by entry id at run time and
run over every `mode == "..."` branch of gate-verdict-grep-shape's seed builder; a shape it closes
over (exit 0) must carry a row in that fixture's verdict tables whose verdict its own oracle
reproduces. Re-derived at this tip: **8 of 10** seeded shapes are receipt-blind (the entry's "three
of the six" predates the bound and near-miss seeds); `no-read` (exit 1) and `no-anchor6` (exit 2)
are receipt-owned. Self-probes in three directions before the corpus: the `comment` row deleted is
reported UNCOVERED, the receipt-owned `no-read` row deleted stays quiet, and `comment` relabelled
GREEN is reported UNREPRODUCED. Known limit: a seed branch deleted together with its row is
invisible. The old receipt's `grep -qE 'BL-040|CHECK_LOADED: 5'` was closable by a comment; the
replacement requires the archive path and the sibling fixture on a non-comment line AND BL-040's
receipt body absent from the fixture. Scored: base 1, fix 0, archive named only in a comment 1,
body pasted 1, sibling fixture absent 9. A read-set re-trace is owed for `backlog-receipt-binding`
(three new reads: the archive, gate-verdict-grep-shape/run.sh, gate-validation.md).

verify: sh h=core/fixtures/gate-verdict-grep-shape/run.sh; b=core/fixtures/backlog-receipt-binding/run.sh; a=docs/backlog.archive.md; [ -f "$h" ] && [ -f "$b" ] && [ -f "$a" ] || exit 9; [ -f core/fixtures/backlog-receipt-binding/.dist-only ] || exit 9; grep -q 'docs/backlog.md' "$h" && exit 9; r="$(awk '$0 == "## BL-040" || index($0, "## BL-040 ") == 1 { f = 1; next } f && /^## / { exit } f && /^verify: sh / { sub(/^verify: sh /, ""); print; exit }' "$a")"; [ -n "$r" ] || exit 9; grep -qF "$r" "$b" && exit 1; grep -qF 'CHECK_LOADED: 5 /,/CHECK_LOADED: 6' "$b" && exit 1; c="$(grep -v '^[[:space:]]*#' "$b")"; grep -qF 'docs/backlog.archive.md' <<<"$c" && grep -qF 'gate-verdict-grep-shape/run.sh' <<<"$c" && exit 0; exit 1

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

## BL-310 — after a transient `cat-file` or `show` failure on a present path, the memo still hands one caller a wrong "absent"

**NOTE.** Found at batch 153 by the `BL-230` tip adversary, reading the 0.637.0 memo change. It
discharges no consumer candidate.

0.637.0 stopped `lib.sh`'s memo from caching a failed git status. `memo_has_path` and `memo_show`
treat 128 as git's answer for an absent path and cache it only after `rev-parse -q --verify`
confirms the path is absent. When that check says the path is present and `cat-file` or `show`
failed anyway, both return the 128 uncached. Their callers in `ledger-reverify.sh` and
`layer-drift.sh` read any non-zero as absent, so each transient failure still produces one wrong
answer; it is no longer served to every later lookup. `memo_has_path` could return 0 there, since
its own check established presence. The cost of the extra `rev-parse` on each distinct absent key
was not measured, and `ledger-reverify`'s `theirs_has_path` is its heaviest caller.

verify: manual

## BL-333 — three "0 ALWAYS" detectors refuse with exit 0 and a stderr line, so the report renders `none` for a scan that never ran

**DEFECT.** Found by the batch-160 contract adversary (contract D3). It is the `BL-230` class that
0.647.0 closes for a detector that exits non-zero, in the form it leaves open: a refusal that
exits 0.

`retired-tokens.sh`, `retired-layer-contract.sh` and `retired-layer-passage.sh` each document
"0 ALWAYS" and each refuses on stderr with exit 0 and no rows: `retired-tokens.sh:119-120`
(preclassify listed no rows), `retired-layer-contract.sh:260-261` (no rulebook shape readable at
base), `retired-layer-passage.sh:77-78` (the rulebook list in `setup-sites.md` unreadable).
`emit-report.sh` discards stderr at every call site, so the section renders `none`, which is the
same text a full scan that matched nothing renders. `--verify` keys refusals on
`^DETECTOR-REFUSED` and cannot see these.

Measured at `1f0a81f3` on the `reconcile-emit-report` seed world, with `setup-sites.md` moved
aside: `retired-layer-passage.sh` exits **0** with **0** bytes of stdout and **1** `refusing to
report clean` line on stderr, and `retired-layer-contract.sh` does the same. `emit-report.sh`
exits 0 and renders both sections as `none`. The render's only `^DETECTOR-REFUSED` line is
`retired-layer-token.sh`'s, which exits 2 on the same input and is the control. With the file in
place, the control run also renders `none` with 0 stderr refusals.

The other two detectors in the contract's list refuse differently, and neither renders `none`.
`predicate-differential.sh` emits a `PREDICATE-UNDECIDABLE` row: with `predicate-sites.md` moved
aside it exits 0 with that one row, and the section shows it. `--verify` counts it as an ordinary
row, not a refusal. `retired-fixtures.sh` emits `HARD-RETIRED-FIXTURE-SCAN-UNAVAILABLE` on stdout
(`:59-61`, `:71-73`; read from the code, not driven), which renders as a `HARD-` row.

The fix changes each detector's contract to exit non-zero on a refusal, which `emit-report.sh`
already renders as `DETECTOR-REFUSED` since 0.647.0. It also changes `apply.sh`'s callers, which
read the same detectors' stdout with stderr discarded: `retired-tokens.sh` at `apply.sh:620` and
`:623`, and `retired-layer-passage.sh` at `:688`. The comment above `:688` states the rlp silence
and calls it the safe direction. `apply.sh` calls neither `retired-layer-contract.sh`,
`retired-fixtures.sh` nor `predicate-differential.sh`.

verify: manual

## BL-336 — `apply.sh`'s refile refusal tells the operator to re-run apply, which the union gate refuses

**NOTE.** Found by the batch-160 tip adversary of 0.647.0. When the `provenance-block.json` refile's
diff fails, 0.647.0 raises a DECISION row and withholds the stamp; its remedy reads "re-run
apply". A bare re-run is refused by the union gate (rc 1, UNDECIDED) because the tree moved since
approval, and that refusal names the procedure that works (re-render, re-approve, re-run). `apply.sh`'s
own comment at `:852-859` calls a remedy of this shape a defect. Reachable only through a
transient staging or diff failure; `--finish` gates on WORKLIST rows and does not stop on it.

verify: manual

## BL-355 — `norm_lines` folds case byte-wise, so an accented capital no longer matches its lower-case form

**DEFECT, latent.** Found by the 0.652.0 tip adversary; introduced by 0.652.0. It discharges no
consumer candidate.

0.652.0 runs `norm_lines`' `tr '[:upper:]' '[:lower:]'` under `LC_ALL=C`
(`core/skills/ai-dlc-update/reconcile/lib.sh:150`), which fixed the Latin-1 abort in its `sed` but
folds only ASCII. Forced: core deletes `1. Élan must always be recorded in the story file before
merge.` (valid UTF-8), a consumer extension carries `- élan must always …`; 0.651.0 reads 1
`RETIRED-LAYER-PASSAGE` row, 0.652.0 reads 0 with "no match". An ASCII case-differing control and a
same-case accented control read 1 on both. `retired-layer-passage.sh:61-66`'s comment says the
locale "cannot manufacture a difference between them", which is false for case.

**Not reachable today:** the rulebook set carries 0 files with a non-ASCII letter byte (control: 63
with an em-dash), and core carries 0 non-ASCII capitals.

**Remedy:** keep `sed` under C. Fold case in the caller's locale only when the staged stream is
valid UTF-8 (`iconv -f UTF-8 -t UTF-8`), otherwise under C. Dropping `LC_ALL=C` from `tr` alone is
wrong: under UTF-8, `tr` on a Latin-1 byte prints "Illegal byte sequence", truncates, and still
exits 0.

**Five NOTEs from the same three adversaries, none a lost verdict today:**
- `norm_lines`' `case` over `"${PIPESTATUS[*]}"` depends on `IFS`: `IFS=$'\n'` makes a healthy run
  return 255, `IFS=''` makes a failed `sed` return 10. No caller sets `IFS`. Respell as an array,
  as `readopt-override.sh:334,354` already do.
- `readopt-override.sh:589-590` ignore `section_of`'s status. Both failing reads `UNCHANGED`, rc 0,
  as before 0.650.0; the later stamp gate still blocks.
- `validate-layer-entries.sh`'s `defined_rules` and `defined_anchors` accept a post-harvest
  `sed`'s exit 1 as "no rule". No natural trigger was found.
- Four `defined_anchors` calls in `validate-layer-entries.sh` (`:1394`, `:1405`, `:2223`, and the
  `:1720` history arm) discard their status, so a forced failure prints a spurious E16 before the
  correct refusal.
- `validate-ci-gates.sh`'s `code_hits` counts with `sed | grep -c || true`; a failed `sed` reads 0,
  which is a false DORMANT finding (exit 1), the blocking direction.

verify: manual



## BL-360 — the other reconcile scripts still read a `<<<` or `<<EOF` input that failed to stage as EMPTY, and several read empty as the CLEAN answer

**DEFECT.** Filed at the close of batch 167, which removed this class from `layer-drift.sh`
(`BL-359`, v0.658.0). It discharges no consumer candidate.

Bash 3.2 stages every here-string AND heredoc to a temp file. When that write fails (`ulimit -f`,
a full or read-only `$TMPDIR`), bash prints `cannot create temp file for here document`, does
NOT run the command, and the site returns 1 — the same status as an empty input or a `grep`
miss. Measured with bash 3.2.57 under `ulimit -f 16` at batch 167: a heredoc loop over 3000 lines
read 0 (control 2 of 2 on a small body), and a here-string read 0 of 3000.

Non-comment `<<<` lines at `9d1fe6c0` (`grep -c` over each file, comment lines excluded):
`emit-report.sh` 5, `self-update-gate.sh` 5, `derivation-differential.sh` 5, `register-drift.sh`
5, `unregistered-drift.sh` 4, `apply.sh` 3, `readopt-override.sh` 4 by `grep -c`, of which 3 are real (the fourth is a literal
`<<<<<<<` inside an echo), `retired-tokens.sh` 2, `relabel-extension-checks.sh` 2, `ledger-reverify.sh`
1, and one each in `preclassify.sh`, `retired-layer-contract.sh`, `retired-layer-token.sh` and
`settings-merge.sh` — 39 real sites. Non-comment `<<EOF` bodies: `apply.sh` 10,
`self-update-gate.sh` 5, `ledger-reverify.sh` 3, `hard-blockers.sh` 2, `unregistered-drift.sh` 2,
`preclassify.sh` 2, and others.

Tiered by reading the code, NOT by forcing each site — re-derive before building:

- **An empty read is the CLEAN answer (fix these first):** `hard-blockers.sh:368`, where an empty
  check-mode loop gives `missing=0` and `--check` passes; `emit-report.sh:842`, where a preclassify
  refusal goes undetected; `apply.sh:2190`, where dangling hooks go unreported; `apply.sh:1878`,
  `self-update-gate.sh:909-910`, `retired-tokens.sh:211-212` and `retired-layer-contract.sh:446`,
  where rows are skipped or read as empty; `ledger-reverify.sh:2280`, zero entries;
  `preclassify.sh:183` and `:344`, where a path is not recognised as setup-sited or machinery; and
  `apply.sh`'s `done <<EOF` loops.
- **An empty read already refuses or is guarded:** `register-drift.sh:238` (exit 1), `:472` (END
  check, exit 3), `:159` (its "unknown" makes the caller refuse); `self-update-gate.sh:828-833`
  (UNDECIDED on an empty set); `settings-merge.sh:100` (fails loud); `unregistered-drift.sh:350/352`
  (grants no exemption).

`apply.sh`, `preclassify.sh`, `ledger-reverify.sh` and `self-update-gate.sh` are BOOTSTRAPPING and
ship alone, each in its own release.

**Remedy direction:** `layer-drift.sh`'s partition at v0.658.0 — `ld_has_line` (a `case`) for
whole-line membership, a status-read pipe or a file staged once for captures (never a pipe into an
early-exiting reader: `printf | grep -q` on a 206 KB haystack under `pipefail` answered NOT-FOUND
20 of 20 at batch 167), loops from a staged file whose write status is read — plus a per-file
spelling arm holding the non-comment `<<<` count at zero.

**Findings carried here**, held in this entry because the live ceiling admitted one filing after
`BL-359` rotated. All three are NOTE-tier.

- **NOTE — the W3 contradiction-awk count has no fixture cell.** A mutant replacing
  `adj_register_contradictions`' `PIPESTATUS[1]` read with `_rc=0` silently loses a
  `HARD-REGISTER-CONTRADICTION` row; `mk_ld_world` never writes a register, and neither the
  `BL-358` nor the `BL-359` receipt world has one. Missing cell: an L5f world with two conflicting
  register records and stdout closed.
- **NOTE — the double-shadow grouping refusal has no fixture cell.** Forced with a PATH `awk` stub:
  tip exits 1, base exits 0 with the pair lost; no cell forces the producer. Lower consequence,
  also surviving: the listing-loop break removed, the list-mode count line printed after a failure,
  an `emit_raw` guard moved after its printf.
- **NOTE — two early-exit readers fed by a pipe remain in `layer-drift.sh`** (`adj_verdict … | head
  -1` and `shadow_parts … | head -1`), status unread and inputs small, so no current risk; the
  v0.658.0 partition covered `<<<` sites only.

Held note (batch 178): the carried DEFECT bullet — a bad `theirs` ref or a missing contract blob
read as an absent contract, switching adjudication off at rc 0 — is struck. It was split out as
`BL-370` and shipped in v0.664.0 (verified bf998dfb): `layer-drift.sh:290` refuses an unresolvable
ref at startup through `ld_resolve_ref`, and `have()` at `:690-705` refuses a path the tree names
but cannot read. The three NOTE bullets stay; this entry stays open for the bootstrapping half.

**Amended at batch 169 (v0.660.0): the non-bootstrapping half is converted, and this entry stays
live for the bootstrapping half.** Line numbers are at `322ef42c` unless marked tip.

**Three premise corrections**, each re-measured under `/bin/bash` 3.2.57 with the failing
`ulimit -f 16` run as the same-invocation control:

- **A read-only `$TMPDIR` does NOT force the failure.** A 20000-byte here-string in a mode-555
  `TMPDIR` returned all 20001 bytes at rc 0; under `ulimit -f 16` the same run printed `cannot
  create temp file for here document` and read nothing. Only `ulimit -f` or a full disk forces it.
- **Under the default SIGXFSZ, a heredoc body over the limit kills the whole script with 153**,
  which reaches a caller as a refusal, not a false clear. The here-string cases measured here did
  not die: they printed `No space left on device` and ran on empty input at rc 0. The faithful
  full-disk model is SIGXFSZ ignored (ENOSPC, no signal), and tier A rests on that model. A cell
  that forces this class must `trap '' XFSZ` and say why.
- **bash does not always report the error at the site line.** A heredoc feeding a `while` inside a
  `for` reported the `for`'s opening line, and a heredoc inside a `$( )` reported the line that
  closes the capture. A here-string reported its own line in every shape measured. Locate a site
  from the code, not from the stderr line number.

**The tier-A set the census forced is wider than the list above.** Each item was forced at
`322ef42c` with SIGXFSZ ignored, and each exits 0:

- `hard-blockers.sh:368` (`--check`): 200 omitted blockers read `(0 total)`.
- `hard-blockers.sh:312` (print): no HARD row and no `0 HARD blockers.` line.
- `relabel-extension-checks.sh:196` and `:227`: "no unlabelled core-number collisions." over a
  live collision.
- `warn-shadowed-local-validators.sh:158`: 0 rows where there were 2.
- `warn-shadowed-local-validators.sh:118`: lib.sh's `ledger_entry_awk` emitter could not be
  staged, and 0 rows resulted.
- `retired-layer-contract.sh:446`: 2 rows where there were 3.
- `retired-tokens.sh:211-212`: the previous path's token files were read as this path's, which
  printed a FALSE row and lost the true one.

These sites were NOT forced, and are tier A by reading: `retired-layer-contract.sh:448`, `:454`;
`readopt-override.sh:446`, `:462`; `warn-shadowed-local-validators.sh:155`; and
`derivation-differential.sh:197`, whose `|| return 0` acquitted the stamp.

**Converted in v0.660.0**, in seven files, with the non-comment `<<<` count now zero in each:

- `hard-blockers.sh:312`, `:368`. A failed staging write exits 1 with `hard-blockers: REFUSED —`,
  because exit 2 already means "report not found".
- `relabel-extension-checks.sh:196`, `:227`. Both anchor sets are staged before either pass, so
  `--apply` moves nothing for an extension it refused on.
- `retired-layer-contract.sh:446` is now a `case` substring test. `:448` and `:454` read files
  staged once, and `:406`'s `cat … || true` now refuses.
- `retired-tokens.sh:211-212` read the blobs `rt_blob` already staged. Every `rt_toks` call now
  refuses on a failed read, which covers `:218` too. The tip adversary found a regression in this
  conversion before merge, and it was fixed then: a NUL-bearing blob read as binary to BSD grep, so
  it lost a true row and printed false ones at rc 0. `toks` now deletes NULs first. The second tip
  adversary found that this NUL strip refused invalid UTF-8, because BSD `tr` in a UTF-8 locale exits
  1 on a Latin-1 byte, so that one `tr` now runs under `LC_ALL=C`.
- `warn-shadowed-local-validators.sh:118` captures the emitter once and reads its status, with no
  lib.sh change. `:155` and `:158` read staged files.
- `readopt-override.sh:428` is a `case` whole-line test. `:446` and `:462` read ids staged by
  `shadow_ids`, which returns 3 inside the `$( )` scans.
- `derivation-differential.sh:197` is a `case` prefix test. **Its four stamp parses (tip `:208`,
  `:223`, `:227`, `:246`) are `printf … | stamp_*` pipes on purpose.** They are captures, and each
  parser reads to EOF before its own `head -1`, so no early-exiting reader sits on the pipe. They
  need no staged file, and converting them to staging would add a failure channel that does not
  exist today.

**Remaining. This is why the entry stays live.** The bootstrapping files ship alone, each in its
own release:

- `apply.sh`: here-strings at tip `:1222`, `:1878`, `:2190`, and ten heredoc loops. **`apply.sh:1319`
  runs `relabel-extension-checks.sh --apply … 2>/dev/null || true`, so relabel's new exit-2 refusal
  is swallowed in `--apply` mode.** The refusal still moves no file, but the apply manifest shows
  no row for it.
- `preclassify.sh:183` (`<<<`) and `:344` (`<<EOF`).
- `ledger-reverify.sh:2280` and three heredoc loops.
- `self-update-gate.sh:828-833` and `:909-910`, plus five heredocs.
- `self-update-fixtures.sh:655` (`GRINVLIST`, the required-input check is skipped) and `:961`
  (`COVEOF`, the coverage join passes). Step 2 runs this file unattended.
- `emit-report.sh:842`, where a preclassify refusal goes undetected, plus tip `:384`, `:444`,
  `:844` and `:845`. `apply.sh:233`'s `--verify` write gate runs this file.
- Outside the bootstrapping set, `readopt-override.sh` still has two heredoc loops. The `--merge`
  span plan (`:558`, tip `:568`) refuses for a multi-anchor override; for a single-anchor one this
  is unverified. The drift panel (`:824`, tip `:834`) is guarded at `:834` (tip `:844`), which
  says the panel is silent because nothing was compared. The here-strings in `register-drift.sh`
  (tip `:159`, `:238`, `:254`, `:386`, `:472`), `unregistered-drift.sh` (`:350`, `:352`, `:552`,
  `:715`), `retired-layer-token.sh:278` and `settings-merge.sh:100` are also unconverted. Each of
  these was tiered as already refusing or guarded, above, or as a NOTE by the census.

**The receipt covers the converted half, and it cannot close this entry until the bootstrapping
half is done too.** Exit 0 means both halves hold. Exit 1 means the entry is live, and the stderr
tag names which half: `BL360-CONVERTED-HALF-REGRESSED` means a converted site regressed, and
`BL360-BOOTSTRAP-HALF-REMAINS` means the converted half holds and the bootstrapping floor does not.
**At this release it exits 1 with the second tag, which the engine reads as STILL-LIVE.** A
receipt over the converted half alone would exit 0 here, and the rotator would archive an entry
whose remaining half has no other home. A distinct exit 3 was tried first. It scored identically,
but `validate-backlog-receipts.sh`'s R4 counts any base exit other than 0 or 1 as out of
population, and the push gate's ceiling is 1.

The first conjunct drives the shipping scripts on seeded worlds under `trap '' XFSZ; ulimit -f 16`:

- `hard-blockers.sh --check` with 200 blockers;
- relabel with 8000 anchors, colliding at 7999, past the point a truncated staging write reaches;
- `warn-shadowed-local-validators.sh` with a 900-name closed entry;
- `retired-layer-contract.sh` with a 20 KB layer file;
- `retired-tokens.sh` with a 16384-byte blob, where the window is one byte.

Each cell accepts either the complete healthy output or the script's own refusal line at non-zero
exit, and fails on anything else. The receipt then holds the non-comment `<<<` count at zero in the
seven converted files.

Exit 9 comes from the preconditions:

- a calibration probe, where a 20000-byte here-string must FAIL and an 8000-byte write must
  succeed under the same limit;
- the spelling scan's self-probe, in both directions, including a literal `<<<<<<<` and a
  comment;
- each cell's unforced run producing its expected rows.

The bootstrapping floor is a SPELLING floor:

- zero non-comment `<<<` in every `reconcile/*.sh`;
- zero heredoc openers in the six bootstrapping files and lib.sh;
- zero `done <<` in `readopt-override.sh`;
- no `|| true` on `apply.sh`'s relabel call.

The release that converts the bootstrapping half should replace this floor with forced cells. A
spelling floor errs toward keeping the entry live.

Scored through `backlog-reverify.sh`'s own `eval` shape, each variant a copy of `reconcile/` that
differs from tip by `diff -rq`. The tag column drops the `BL360-` prefix:

| variant | exit | tag |
|---|---|---|
| tip (`afe58b5b`) | 1 | BOOTSTRAP-HALF-REMAINS |
| base `322ef42c` | 1 | CONVERTED-HALF-REGRESSED |
| BL-360 fix alone (`2f598a86`) | 1 | BOOTSTRAP-HALF-REMAINS |
| BL-356 fix alone | 1 | CONVERTED-HALF-REGRESSED |
| the converted scripts stubbed to `exit 0` | 9 | |
| the converted scripts stubbed to a refusal (`exit 2`) | 9 | |
| `retired-tokens.sh` base here-string restored | 1 | CONVERTED-HALF-REGRESSED |
| `hard-blockers.sh` staging status replaced by `\|\| true` | 1 | CONVERTED-HALF-REGRESSED |
| `warn-shadowed-local-validators.sh` staging status replaced by `\|\| true` | 1 | CONVERTED-HALF-REGRESSED |
| `retired-layer-contract.sh` base here-string restored | 1 | CONVERTED-HALF-REGRESSED |
| `relabel-extension-checks.sh` staging status replaced by `\|\| true` | 1 | CONVERTED-HALF-REGRESSED |
| `readopt-override.sh` base here-string restored | 1 | CONVERTED-HALF-REGRESSED |
| second spelling (`retired-tokens.sh` fed by `< <(printf …)`) | 1 | BOOTSTRAP-HALF-REMAINS |
| the bootstrapping floor satisfied (reachability, not a fix) | 0 | |

The last row shows exit 0 is reachable. It was built by moving lib.sh's emitters to sidecar
files, deleting the floor-matching lines the cells never execute, and dropping the `|| true`.
`readopt-override.sh`, `derivation-differential.sh` and `hard-blockers.sh`'s print mode are held
by the spelling conjunct only; the relabel collision was moved to 7999 after a collision at 24
let the `|| true` mutant survive. Through `scripts/backlog-reverify.sh` on a scratch ledger, with
an `exit 0` control entry reading CLOSE-CANDIDATE, this entry reads STILL-LIVE in about 30s.

**Amended at batch 170 (v0.661.0): lib.sh's three emitters are literals, and this entry stays
live.** `nrm_awk`, `ledger_entry_awk` and `backlog_entry_label_awk` were `cat <<'AWK'` heredocs.
Each is now `printf '%s\n' '<body>'` with the body as a single-quoted literal, so there is no
staging step that can fail. The one apostrophe in a body, a comment in `ledger_entry_awk`, is
spelled `'\''`. `core/scripts/validate-layer-entries.sh`'s `nrm_awk` changed identically, because
I40 byte-binds it to lib.sh's copy. The callers are not edited. Once the emitter cannot fail,
`"$(ledger_entry_awk)"` can come back empty only on a fork failure, which fails the whole `$( )`.
Measured under `/bin/bash` 3.2.57 with `trap '' XFSZ; ulimit -f 0`, capturing `x="$(emitter)"`
under the limit and writing it to disk outside the limit:

| emitter | base `b0c310a3` | the 0.661.0 tree |
|---|---|---|
| `nrm_awk` | rc 1, 0 B | rc 0, 109 B |
| `ledger_entry_awk` | rc 1, 0 B | rc 0, 2495 B |
| `backlog_entry_label_awk` | rc 1, 0 B | rc 0, 342 B |

Each tip capture under the limit is byte-identical to its unforced output. Each emitter's healthy
output at tip is byte-identical to base (`cmp -s`, all three), so every awk program these emitters
feed is unchanged. lib.sh leaves the **Remaining** list above. Its heredoc-opener count is now 0.

**The receipt CANNOT distinguish this release from base.** It exits 1 with
`BL360-BOOTSTRAP-HALF-REMAINS` on both `b0c310a3` and the 0.661.0 tree, run by `bash -c` from a
`git archive` extraction of each. Its here-string loop over every `reconcile/*.sh` fires first,
on the here-strings still in the bootstrapping files, so the heredoc scan that names lib.sh never
runs on either tree. The guard for this half is the `procsub-staged-refusal` fixture, whose
emitter cells force each emitter under the write limit.

verify: sh R=core/skills/ai-dlc-update/reconcile; for f in hard-blockers relabel-extension-checks warn-shadowed-local-validators retired-layer-contract retired-tokens readopt-override derivation-differential; do [ -f "$R/$f.sh" ] || exit 9; done; w="$(mktemp -d)" || exit 9; F() { ( trap '' XFSZ; ulimit -f 16; "$@" ); }; c="$(F bash -c 'wc -c <<<"$1"' _ "$(printf '%020000d' 0)" 2>/dev/null)"; case "$c" in *[1-9]*) exit 9 ;; esac; F bash -c 'printf "%08000d" 0 > "$1"' _ "$w/cal" 2>/dev/null; [ "$(wc -c < "$w/cal" | tr -d ' ')" -eq 8000 ] || exit 9; A='/^[[:blank:]]*#/ {next} { l=$0; gsub(/<<<<+/, "", l); if (l ~ /<<</) n++ } END {print n+0}'; printf '%s\n' 'a <<<"$b"' '  # c <<<"$d"' 'echo "<<<<<<< x"' > "$w/sp"; [ "$(awk "$A" "$w/sp")" -eq 1 ] || exit 9; : > "$w/ld"; i=0; while [ $i -lt 200 ]; do printf 'HARD-UNREGISTERED-CORE-DRIFT\tskills/ai-dlc/steps/file-number-%04d-padding-padding.md\tx\n' $i; i=$((i+1)); done > "$w/ud"; echo '# report' > "$w/rep"; hb() { bash "$R/hard-blockers.sh" --check "$w/rep" --ld-rows "$w/ld" --ld-rc 0 --ud-rows "$w/ud" --ud-rc 0 "$w" base "$w" theirs; }; hb > "$w/hbh" 2>&1; [ "$(grep -c '^FAIL' "$w/hbh")" -eq 200 ] || exit 9; F hb > "$w/hbf" 2>&1; [ "$(grep -c '^FAIL' "$w/hbf")" -eq 200 ] || grep -q '^hard-blockers: REFUSED' "$w/hbf" || { echo BL360-CONVERTED-HALF-REGRESSED >&2; exit 1; }; C="$w/rx"; mkdir -p "$C/.claude/skills/ai-dlc/extensions" || exit 9; i=1; while [ $i -le 8000 ]; do printf '### %d. Check title\nbody\n' $i; i=$((i+1)); done > "$C/.claude/skills/ai-dlc/gate-validation.md"; printf -- '---\nkind: check\nid: mine\nhooks: gate-validation.md\n---\n\n### 7999. My check\ntext\n' > "$C/.claude/skills/ai-dlc/extensions/x.md"; bash "$R/relabel-extension-checks.sh" "$C" > "$w/rxh" 2>&1; grep -qF '[ext:mine]' "$w/rxh" || exit 9; F bash "$R/relabel-extension-checks.sh" "$C" > "$w/rxf" 2>&1; grep -qF '[ext:mine]' "$w/rxf" || grep -q '^relabel: REFUSED' "$w/rxf" || { echo BL360-CONVERTED-HALF-REGRESSED >&2; exit 1; }; C="$w/ws"; mkdir -p "$C/_bmad-output/ai-dlc-update" "$C/scripts/ai-dlc" "$C/scripts/ai-dlc-local/sub" "$C/.claude" || exit 9; echo 'echo core' > "$C/scripts/ai-dlc/validate-zz.sh"; echo 'echo fork' > "$C/scripts/ai-dlc-local/validate-zz.sh"; echo 'echo fork2' > "$C/scripts/ai-dlc-local/sub/validate-zz.sh"; { printf '# ledger\n\n## PC-S1-THING fork of validate-zz.sh\n\nADOPTED UPSTREAM in 0.1.0.\n\n'; i=0; while [ $i -lt 900 ]; do printf 'names aaaa-padding-name-%04d.sh\n' $i; i=$((i+1)); done; } > "$C/_bmad-output/ai-dlc-update/push-candidate-ledger.md"; bash "$R/warn-shadowed-local-validators.sh" --root "$C" > "$w/wsh" 2>&1; [ "$(grep -c '^RETIRE-CANDIDATE' "$w/wsh")" -eq 2 ] || exit 9; F bash "$R/warn-shadowed-local-validators.sh" --root "$C" > "$w/wsf" 2>&1; [ "$(grep -c '^RETIRE-CANDIDATE' "$w/wsf")" -eq 2 ] || grep -q '^warn-shadowed-local-validators: REFUSED' "$w/wsf" || { echo BL360-CONVERTED-HALF-REGRESSED >&2; exit 1; }; g() { local d="$1"; shift; git -C "$d" -c user.email=r@r -c user.name=r -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }; D="$w/rd"; mkdir -p "$D/core/skills/ai-dlc/steps" || exit 9; g "$D" init -q || exit 9; printf -- '- Label: /cmd\nuse {tok}\n' > "$D/core/skills/ai-dlc/steps/a.md"; printf 'small\n' > "$D/core/skills/ai-dlc/steps/b.md"; printf 'small\n' > "$D/core/skills/ai-dlc/steps/c.md"; { g "$D" add -A && g "$D" commit -qm b; } >/dev/null 2>&1 || exit 9; B="$(git -C "$D" rev-parse HEAD)"; { g "$D" rm -q core/skills/ai-dlc/steps/b.md core/skills/ai-dlc/steps/c.md && g "$D" commit -qm t; } >/dev/null 2>&1 || exit 9; T="$(git -C "$D" rev-parse HEAD)"; C="$w/rc"; mkdir -p "$C/.claude/skills/ai-dlc/extensions" "$C/.claude/skills/ai-dlc/overrides" || exit 9; { echo 'see steps/b.md for the gate'; head -c 20000 /dev/zero | tr '\0' p; echo; } > "$C/.claude/skills/ai-dlc/extensions/e.md"; printf 'see .claude/skills/ai-dlc/steps/c.md and core/skills/ai-dlc/steps/b.md\n' > "$C/.claude/skills/ai-dlc/overrides/o.md"; printf 'nothing here\n' > "$C/.claude/skills/ai-dlc/extensions/n.md"; bash "$R/retired-layer-contract.sh" "$D" "$B" "$T" "$C" > "$w/rch" 2>/dev/null; [ "$(grep -c '^RETIRED-LAYER-CONTRACT' "$w/rch")" -eq 3 ] || exit 9; F bash "$R/retired-layer-contract.sh" "$D" "$B" "$T" "$C" > "$w/rcf" 2> "$w/rcfe"; rc=$?; cmp -s "$w/rch" "$w/rcf" || { [ "$rc" -ne 0 ] && grep -q '^retired-layer-contract: .*no verdict' "$w/rcfe"; } || { echo BL360-CONVERTED-HALF-REGRESSED >&2; exit 1; }; D="$w/td"; mkdir -p "$D/core/scripts" || exit 9; g "$D" init -q || exit 9; mb() { h="x=\$ROOT/$1"; printf '%s\n' "$h" > "$2"; head -c $((16384 - ${#h} - 1)) /dev/zero | tr '\0' p >> "$2"; }; mb old-z "$D/core/scripts/z.sh"; printf 'x=$ROOT/old-b\nsmall\n' > "$D/core/scripts/b.sh"; { g "$D" add -A && g "$D" commit -qm b; } >/dev/null 2>&1 || exit 9; B="$(git -C "$D" rev-parse HEAD)"; mb new-z "$D/core/scripts/z.sh"; printf 'x=$ROOT/new-b\nsmall\n' > "$D/core/scripts/b.sh"; { g "$D" add -A && g "$D" commit -qm t; } >/dev/null 2>&1 || exit 9; T="$(git -C "$D" rev-parse HEAD)"; [ "$(git -C "$D" cat-file -s "${B}:core/scripts/z.sh")" -eq 16384 ] || exit 9; C="$w/tc"; mkdir -p "$C/scripts/ai-dlc" || exit 9; git -C "$D" show "${B}:core/scripts/z.sh" > "$C/scripts/ai-dlc/z.sh"; git -C "$D" show "${B}:core/scripts/b.sh" > "$C/scripts/ai-dlc/b.sh"; echo 'uses $ROOT/old-b too' >> "$C/scripts/ai-dlc/z.sh"; printf 'X\tcore/scripts/b.sh\tscripts/ai-dlc/b.sh\tCLASSIFY\nX\tcore/scripts/z.sh\tscripts/ai-dlc/z.sh\tCLASSIFY\n' > "$w/rows"; bash "$R/retired-tokens.sh" --bucket-rows "$w/rows" "$D" "$B" "$T" "$C" > "$w/rth" 2>/dev/null; [ "$(cut -f2,3 "$w/rth" | tr '\t\n' ':;')" = 'core/scripts/b.sh:$ROOT/old-b;core/scripts/z.sh:$ROOT/old-z;' ] || exit 9; F bash "$R/retired-tokens.sh" --bucket-rows "$w/rows" "$D" "$B" "$T" "$C" > "$w/rtf" 2> "$w/rtfe"; rc=$?; cmp -s "$w/rth" "$w/rtf" || { [ "$rc" -ne 0 ] && grep -q '^retired-tokens: .*no verdict' "$w/rtfe"; } || { echo BL360-CONVERTED-HALF-REGRESSED >&2; exit 1; }; for f in hard-blockers relabel-extension-checks warn-shadowed-local-validators retired-layer-contract retired-tokens readopt-override derivation-differential; do [ "$(awk "$A" "$R/$f.sh")" -eq 0 ] || { echo BL360-CONVERTED-HALF-REGRESSED >&2; exit 1; }; done; for f in "$R"/*.sh; do [ "$(awk "$A" "$f")" -eq 0 ] || { echo BL360-BOOTSTRAP-HALF-REMAINS >&2; exit 1; }; done; H='/^[[:blank:]]*#/ {next} { l=$0; gsub(/<<<+/, "", l); if (l ~ /<<-?[\047"]?[A-Za-z_]/) n++ } END {print n+0}'; for f in apply preclassify ledger-reverify self-update-gate self-update-fixtures emit-report lib; do [ -f "$R/$f.sh" ] || exit 9; [ "$(awk "$H" "$R/$f.sh")" -eq 0 ] || { echo BL360-BOOTSTRAP-HALF-REMAINS >&2; exit 1; }; done; [ "$(awk '/^[[:blank:]]*#/ {next} /done <</ {n++} END {print n+0}' "$R/readopt-override.sh")" -eq 0 ] || { echo BL360-BOOTSTRAP-HALF-REMAINS >&2; exit 1; }; grep -q 'relabel-extension-checks\.sh.*|| true' "$R/apply.sh" && { echo BL360-BOOTSTRAP-HALF-REMAINS >&2; exit 1; }; exit 0

## BL-364 — 29 path listings in `reconcile/` still run under the default `core.quotePath`, so a non-ASCII path reaches their readers C-quoted

**DEFECT.** Filed at batch 170 by the contract adversary and the docs hand. It discharges no
consumer candidate. `BL-356` bullet 3 was fixed at two producers in v0.661.0:
`memo_diff_name_status` in lib.sh, and preclassify's relocation `ls-tree`. Every other
`git ls-tree`, `git ls-files`, `git diff --name-only` or `git diff --name-status` call in
`core/skills/ai-dlc-update/reconcile/` still lists paths under the default `core.quotePath`. Git
C-quotes a non-ASCII name there, so `core/scripts/café.sh` arrives as
`"core/scripts/caf\303\251.sh"`. A reader that compares that line against a raw path, maps it to a
consumer path or shows it to git again treats the file as absent. `BL-356` measured the loss on one
reader: its row disappears at rc 0.

Reach today is zero, measured this batch. The distribution's 829 tracked paths and the reference
consumer's 11882 include 0 quoted ones, against a same-invocation control repo holding `café.sh`
that listed 1. That makes this a latent defect, not a live one. It stays DEFECT-tier because a
non-ASCII path would be dropped silently, and the drop reads as a clean answer.

**The census.** These are the sites at `4fff688e` (v0.661.0), one line per invocation, comment lines excluded.
The receipt's own grammar enumerates the same 35 sites: 29 unflagged and 6 already carrying
`core.quotePath=false`. A scan for `git -C … \` continuation lines found 0, against a control of
207 continuation lines of any kind in the same files.

- **`memo_ls_tree`, lib.sh `:1105` and `:1107`, the first row.** This is the shared memoised
  `ls-tree -r --name-only`. It was deliberately left out of v0.661.0. Its readers each compare its
  lines against their own spelling of a path, so flipping it changes all of their outputs at once,
  unaudited, in a bootstrapping file. The readers are `layer-drift.sh:1297`,
  `retired-layer-contract.sh:200` (fallback `:201`), `retired-layer-token.sh:168` (fallback
  `:169`), `retired-fixtures.sh:85` (fallback `:86`) and `unregistered-drift.sh:597` (fallback
  `:607`). Each fallback is its own unflagged `ls-tree` and has to change together with the memo.
- **`apply.sh:1423`**, the manifest glob expansion `ls-tree --name-only "$THEIRS" -- core/scripts/`.
  It has the same shape as preclassify's relocation listing, fixed in v0.661.0. It maps each name to
  `scripts/ai-dlc/…` and has not been traced.
- `apply.sh`: `:390` and `:1523` (mode lookups on one named path, where the path comes from the
  caller), `:571` (a range emptiness test), `:850` (moved paths fed to `map_consumer`), `:1719`
  (executable-bit listing fed to `consumer_path`), and `:2345` (a consumer `ls-files` count).
- `emit-report.sh`: `:242` (range emptiness) and `:343` (an orientation read of one named path).
- `ledger-reverify.sh`: `:1027` (range emptiness), `:1327` (the consumer-to-core map table),
  `:1393` (`theirs_basename_matches`, a basename compare), and `:1480` (a consumer `ls-files`
  presence test).
- `preclassify.sh`: `:393`
  (`mode_at_theirs`), and `:453` (the `core_manifest` glob expansion fed to `map_consumer`).
- `predicate-differential.sh:112` (`ls-files --with-tree`, each name shown again with `git show`).
- `retired-fixtures.sh:128` (a presence test on one named directory).
- `retired-layer-token.sh:265` (the rename map, `diff -M --name-status`).
- `self-update-fixtures.sh:931` (the diff-side coverage join).
- `self-update-gate.sh`: `:766` (range emptiness), `:880` (the rulebook candidate set), and `:1125`
  (the changed `core/scripts/` set).
- `unregistered-drift.sh:468` (a range line count).

Sites that only test whether the output is empty, or count its lines, cannot lose a row to quoting.
Sites that list the paths of ONE named path already know the raw name and use the output only for
mode or presence. Tier these by reading each reader before converting anything. The four already
flagged are lib.sh `:1128` and `:1130`, `preclassify.sh:539`, and `retired-tokens.sh:200`.
`apply.sh`, `preclassify.sh`, `ledger-reverify.sh`, `self-update-gate.sh`, `self-update-fixtures.sh`,
`emit-report.sh` and lib.sh are BOOTSTRAPPING and ship alone.

**Remedy direction:** add `-c core.quotePath=false` at the producer, or read `-z`. Convert per
reader, each with a fixture cell on a world holding `plain.sh` and `café.sh`, on the model of
`procsub-staged-refusal`'s quotePath cell.

- **NOTE — the dist-only `{ ledger_entry_awk; …; cat <<'AWK' … } > "$AWKF"` writers now produce a
  truncated program where they produced an empty one.** The writers are
  `scripts/backlog-reverify.sh:112`, `scripts/backlog-rotate.sh:266`,
  `scripts/validate-backlog-size.sh:129` and `scripts/validate-backlog-receipts.sh:625`. Measured on
  that shape under `/bin/bash` 3.2.57 with `trap '' XFSZ; ulimit -f 1`: at base the group exited 0
  and wrote 36 bytes, the trailing heredoc only, because the emitter's own heredoc failed to stage.
  At tip it exited 1 and wrote 1024 bytes, a prefix of `ledger_entry_awk` that ends mid-program.
  Each writer's status handling decides whether either shape reaches awk. That was not audited
  here.

The receipt counts the unflagged listing sites. It exits 1 while any remain and names the count in
the `BL364-UNQUOTED-LISTING-SITES` tag. A site passes when its line carries `core.quotePath=false`
or a `-z` flag. The grammar is self-probed on five seeded lines first: one unflagged `ls-tree`
counts, one flagged `diff --name-only` passes, and a commented listing, an echoed `git ls-tree`
and a `diff -U0` are ignored. It exits 9 if that probe fails, if the corpus holds fewer than 20
files or 20 sites, or if no flagged site is found, which would mean the grammar cannot see the
four fixed ones. Scored through `backlog-reverify.sh`'s own `eval` shape, from the root of a
`git archive` extraction of `9b8d1afc`:

| variant | exit | tag |
|---|---|---|
| base `b0c310a3` | 1 | UNQUOTED-LISTING-SITES 34 of 35 |
| tip `9b8d1afc` (before `machinery_paths` was fixed) | 1 | UNQUOTED-LISTING-SITES 31 of 35 |
| landed `4fff688e` | 1 | UNQUOTED-LISTING-SITES 29 of 35 |
| every unflagged site given `-c core.quotePath=false` (31 changed lines) | 0 | |
| the same, with `apply.sh:1423` restored | 1 | UNQUOTED-LISTING-SITES 1 of 35 |
| the same, with `memo_ls_tree` read by `-z` instead of the flag | 0 | |
| no `reconcile/` directory | 9 | |
| a two-file corpus | 9 | |
| `awk` stubbed to print nothing | 9 | |

verify: sh R=core/skills/ai-dlc-update/reconcile; [ -f "$R/lib.sh" ] || exit 9; set -- "$R"/*.sh; [ "$#" -ge 20 ] || exit 9; w="$(mktemp -d)" || exit 9; P='/^[[:blank:]]*#/ {next} /git -C "[^"]*"/ && (/ ls-(tree|files)[[:blank:]]/ || (/ diff[[:blank:]]/ && /--name-(only|status)/)) { if (/core[.]quotePath=false/ || / -z[[:blank:]]/) f++; else u++ } END {print u+0, f+0}'; printf '%s\n' 'x="$(git -C "$D" ls-tree -r --name-only "$T")"' 'git -C "$D" -c core.quotePath=false diff --name-only "$B" "$T"' '  # git -C "$D" ls-tree --name-only "$T"' 'echo "git ls-tree exited"' 'git -C "$D" diff -U0 "$B"' > "$w/p.sh" || exit 9; [ "$(awk "$P" "$w/p.sh")" = "1 1" ] || exit 9; o="$(awk "$P" "$@")" || exit 9; u="${o% *}"; f="${o#* }"; [ "$f" -ge 1 ] && [ "$((u + f))" -ge 20 ] || exit 9; [ "$u" -eq 0 ] && exit 0; echo "BL364-UNQUOTED-LISTING-SITES $u of $((u + f))" >&2; exit 1


## BL-374 — the shared reconcile memo caches a missing SUBTREE as an absent path, and serves that answer to later processes

**DEFECT.** From the batch 173 adversary, found while attacking the `BL-370` fix. It discharges no
consumer candidate.

`memo_has_path` and `memo_show` in `reconcile/lib.sh` cache a git status of 128 only when
`_ai_dlc_memo_absent` says the path is genuinely absent. That oracle is `rev-parse -q --verify
<ref>:<path>` exiting 1, and `rev-parse` exits 1 in exactly that way when the path's SUBTREE or the
ROOT tree is the missing object. So a read failure is written into the memo as an absence. The memo
is shared across processes through `AI_DLC_RECONCILE_MEMO`, so every later reader in the same render
gets the cached absence even after the object is back. The adversary measured it: process 1 cached
128 while the subtree was missing, process 2 after the restore got the cached 128, and a no-memo
control read 0. `preclassify.sh`'s `blob_hash` (`memo_rev_parse`) uses the same oracle to decide
`MISSING`, so the same missing subtree buckets a present file as `MISSING` there.

**Remedy direction.** Use the discriminator `layer-drift.sh`'s `have` adopted in `BL-370`: `ls-tree
--full-tree <ref> -- <path>`, where rc 0 with no line is absent, and rc 0 with a line or any non-zero
rc is a read failure that must stay uncached. Apply it to `_ai_dlc_memo_absent` and to
`preclassify.sh`'s `MISSING` decision.

The receipt builds a throwaway repo holding `a/b/f.txt` and `top.txt`. Through `lib.sh` with the
memo pointed at its own `mktemp` directories, it first requires a present path to read 0 and an
absent one non-zero in a fresh memo, and memo `m` to hold a file after one present-path query, so
the memo was actually used (else 9). It then moves the `a/b` tree object aside, requires
`ls-tree` on the path to fail (the seed took, else 9), queries `a/b/f.txt` into memo `m`, restores
the object, requires a fresh memo `n` to read 0 (the object is back, else 9), and queries memo `m`
again. It exits 0 only when that second query reads 0. Scored on this tree: live 1 (`p1=128
p2=128`); `_ai_dlc_memo_absent` rewritten to the `ls-tree` rule 0; `_ai_dlc_memo_absent` that never
answers absent, so 128 is never cached, 0; a `lib.sh` that fails to source 9; a memo that is
never used, so every query goes to git direct, 9.

verify: sh L="$PWD/core/skills/ai-dlc-update/reconcile/lib.sh"; [ -f "$L" ] || exit 9; w="$(mktemp -d)" || exit 9; g() { git -C "$w/r" -c user.name=r -c user.email=r@r "$@"; }; git init -q "$w/r" || exit 9; mkdir -p "$w/r/a/b" || exit 9; echo x > "$w/r/a/b/f.txt" || exit 9; echo y > "$w/r/top.txt" || exit 9; g add -A || exit 9; g commit -qm s || exit 9; t="$(g rev-parse HEAD:a/b)" || exit 9; o="$w/r/.git/objects/$(printf %s "$t" | cut -c1-2)/$(printf %s "$t" | cut -c3-)"; [ -f "$o" ] || exit 9; q() { AI_DLC_RECONCILE_MEMO="$1" bash -c '. "$1" >/dev/null 2>&1 || exit 9; memo_has_path "$2" HEAD "$3"; echo "$?"' _ "$L" "$w/r" "$2" 2>/dev/null; }; mkdir "$w/m" "$w/n" "$w/k" || exit 9; [ "$(q "$w/k" top.txt)" = 0 ] || exit 9; [ "$(q "$w/k" nope.txt)" = 0 ] && exit 9; [ "$(q "$w/m" top.txt)" = 0 ] || exit 9; [ -n "$(ls -A "$w/m")" ] || exit 9; mv "$o" "$w/obj" || exit 9; g ls-tree --full-tree HEAD -- a/b/f.txt >/dev/null 2>&1 && exit 9; p1="$(q "$w/m" a/b/f.txt)"; [ "$p1" = 0 ] && exit 9; mv "$w/obj" "$o" || exit 9; [ "$(q "$w/n" a/b/f.txt)" = 0 ] || exit 9; p2="$(q "$w/m" a/b/f.txt)"; [ "$p2" = 0 ] && exit 0; echo "BL374-MISSING-SUBTREE-CACHED-AS-ABSENT p1=$p1 p2=$p2" >&2; exit 1

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

## BL-376 — `layer-drift.sh`'s unguarded BASE reads turn a missing base blob into more drift

**NOTE.** From the batch 173 adversary, held at the time by the backlog ceiling. The literal
`git_show "$BASE"` reads (`layer-drift.sh`, three sites) and the two `git_show "$base_sha"` reads
treat a blob they cannot read as an empty file, so a missing base object reports MORE drift or a
`NEW-THIS-PULL` tag rather than fewer rows. It fails toward reporting, never toward a clean sheet,
which is why it is a NOTE. The fix is the `have()` discipline `BL-370` shipped: tell absent from
unreadable before reading. Re-derive the line numbers before building; they move.

verify: manual

## BL-378 — the suite-pole baseline still names `ledger-reverify` after the pole moved

**NOTE.** v0.665.0's 12-way gate reported the pole as `gate-adjudication-mutants` at 490s against a
baseline row for `ledger-reverify` at 628s (band 20%, ceiling 754s), with the note "a row pinned to
a unit that is no longer longest passes while watching the wrong number". Re-baseline
`docs/suite-pole-baseline.tsv` from a quiet 12-way run. The 6-way gates earlier in batch 173 skipped
this phase on the pool-width mismatch, because the operator's shell profile sets
`AI_DLC_FIXTURE_JOBS=6`.

verify: manual

## BL-381 — `layer-adjudication-tier` Part 11 world E fails to build when git packs the fixture's store

**NOTE.** Seen on the 0.667.0 gate at `bc1ed530`, 1 of 218 units, and once before in the recorded
failures; it passed alone and on the next gate. Part 11 world E hides the contract's loose blob to
build a missing-object store, and refuses as `FIXTURE ERROR` when the blob is "readable but not
loose (in-pack: 22 packs: 1)". The packer is `git maintenance run --auto`, which every `commit`
runs; on git 2.54 it repacks once two loose objects sit in the `objects/17` sample bucket, and it
is governed by `maintenance.auto`, NOT `gc.auto` — measured, `-c gc.auto=0` packs exactly as the
default does. The packing commits are into `$DIST` (`seed.sh` base and theirs, `run.sh` Parts 4b and
5), and world E is a later `cp -R "$DIST"`. It fails toward a FIXTURE ERROR, never toward a false
pass, which is why it is a NOTE.

Held note (batch 178): REPRODUCED and fixed. On origin/main's fixture code, two unreachable loose
objects written into `objects/17` before the seed's first commit turn world E into the filed
refusal every run (76 ok, 1 FAIL, "in-pack: 13 packs: 2"); unforced, the same tree passes.
`seed.sh` now sets `maintenance.auto false` in `$DIST`'s own config, and `run.sh` Part 12 forces
the trigger on a copy of the distribution, drives the same world E build (now `p11_build_e`, shared
with Part 11), and kills a mutant seed without the line on world E's own "readable but not loose"
refusal. A probe on a fresh repository skips Part 12 under a git that does not pack on this
trigger. No other fixture reads loose-object files: `objects/` across `core/fixtures`, `scripts`,
`.githooks` and `core/scripts` hits only this fixture and a comment in `self-update-join-gate`.

verify: sh S=core/fixtures/layer-adjudication-tier/seed.sh; [ -f "$S" ] || exit 9; d=$(mktemp -d) || exit 9; r=""; trap 'rm -rf "$d" ${r:+"$r"}' EXIT; f() { for p in 'bl381 unreachable 43' 'bl381 unreachable 778'; do s=$(printf '%s\n' "$p" | git -C "$1" hash-object -w --stdin) || return 9; case "$s" in 17*) : ;; *) return 9 ;; esac; done; printf 'f\n' > "$1/bl381-forcing"; git -C "$1" add -A && git -C "$1" -c maintenance.autoDetach=false commit -qm forcing >/dev/null 2>&1 || return 9; }; ip() { git -C "$1" count-objects -v | awk '$1=="in-pack:"{print $2}'; }; c="$d/ctl"; mkdir -p "$c" && git -C "$c" init -q && git -C "$c" config user.email f@x && git -C "$c" config user.name f || exit 9; printf 'a\n' > "$c/a"; git -C "$c" add -A && git -C "$c" commit -qm one >/dev/null 2>&1 || exit 9; f "$c" || exit 9; [ "$(ip "$c")" -gt 0 ] || exit 9; r=$(bash "$S" 2>/dev/null) && [ -d "$r/dist/.git" ] || exit 9; f "$r/dist" || exit 9; n=$(ip "$r/dist"); [ -n "$n" ] || exit 9; [ "$n" -eq 0 ]

## BL-391 — step 2 still commits locally when its gated push fails, which the same file calls the stranded-branch shape

**NOTE. Found by the BL-389 correction hand at batch 176, not shipped.** The step-2 cycle bullet in
`core/skills/ai-dlc-update/SKILL.md` reads "If there is no remote / push fails, commit locally and note
it". The UN-SYNCED paragraph 0.673.0 added, and the gate paragraph beside it, both describe a local
self-update commit as the PC-S308 orphan: `skill_version` advanced on a commit that never merges. This
path is a push failing AFTER the gate returned OK on an in-sync branch, so it is not the UN-SYNCED case
BL-389 fixed and 0.673.0 did not make it worse. Discharges no consumer candidate.

verify: manual


## BL-399 — the `--cite` stdout vocabulary of `validate-steering-budget.sh` has no owner in the vocabulary index

**NOTE. Found by the BL-390 contract hand at batch 177, not shipped.** `validate-steering-budget.sh --cite`
prints one of `MATCH`, `NOMATCH`, `NOMATCH-NO-RECORDS` and, since 0.674.0, `NOMATCH-TRANSCRIPT-PRUNED`.
`docs/vocabulary-index.md` names none of them (0 hits for `NOMATCH`, against a control of 1 for
`EXAMINED NOTHING` in the same file), so no arm binds the set its readers compare against. Today every
reader compares one member exactly (`validate-adversarial-convergence.sh` against `NOMATCH-NO-RECORDS`)
or reads the exit status only, so a new member cannot silently pass a gate. Discharges no consumer
candidate.

Held note (batch 178): new arm **I117** in `scripts/validate-enforcement-map.sh` owns the set and carries the
`# vocabulary:` marker; the row renders all four members from the owner. The emitter grammar is
`CITE_VERDICTS_AWK` in `scripts/render-vocabulary-index.sh` (slug `cite-verdicts`), lifted and run by I117
rather than copied. It reads every `console.log` inside the `if (CITE) {` block: ternary arms, a template
literal's leading word, and plain literals. I117 refuses an emitter that grammar cannot spell, a member
outside the `MATCH` / `NOMATCH-<WORD>` shape, and a quoted verdict-shaped literal in any core `.sh` that is
not a member. Its false-positive set was 15 sites and 0 findings, and the owner's own sites are skipped. The
recorded limit is that an unquoted compare is invisible. Pinned by renderer probes in both directions,
`vocabulary-index` (I814 seed), and `enforcement-map-derivations` A46-A51. The suite pays for it in
`FORK_BUDGET` 3194 -> 3202 (base 3186, tip 3196, I117 +9). Receipt scored: tip 1, fix 0, marker on an
existing arm 1, three-member extractor 1, hand-typed index row 1.

verify: sh O=core/scripts/validate-steering-budget.sh; [ -f "$O" ] && grep -q '^if (CITE) {$' "$O" || exit 9; B="$(printf '\140')"; R="$(grep -F "| ${B}${O}${B} |" docs/vocabulary-index.md)"; [ -n "$R" ] || exit 1; bash scripts/render-vocabulary-index.sh --check >/dev/null 2>&1 || exit 1; M="$(printf '%s' "$R" | cut -d'|' -f3)"; for v in MATCH NOMATCH NOMATCH-NO-RECORDS NOMATCH-TRANSCRIPT-PRUNED; do case "$M" in *"${B}${v}${B}"*) ;; *) exit 1 ;; esac; done; I="$(printf '%s' "$R" | cut -d'|' -f5 | tr -d ' ')"; case "$I" in I[0-9]*) ;; *) exit 1 ;; esac; D="$(mktemp -d)" || exit 9; for x in core scripts .githooks templates VERSION; do cp -R "$x" "$D/$x" || exit 9; done; awk '/^  console\.log\("NOMATCH"\); process\.exit\(2\);$/ && !d { print "  console.log(v); process.exit(2);"; d = 1 } { print }' "$O" > "$D/$O"; cmp -s "$O" "$D/$O" && exit 9; out="$(cd "$D" && bash scripts/validate-enforcement-map.sh --arms "$I" 2>&1)"; grep -q "^FAIL: $I" <<<"$out"
