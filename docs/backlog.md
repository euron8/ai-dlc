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

verify: manual -- this entry records a gap and names a candidate, not a receipt. Do not close it
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

verify: manual -- this entry records a gap, not a receipt. Do not close it on a green
`layer-drift.sh` run; that green is the defect.

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
subject (`b3debba3` for PC-S308) still reads NAMED-UPSTREAM, because a per-id subject path is
recorded nowhere.

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

verify: sh L="$PWD/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"; [ -f "$L" ] || exit 9; w="$(mktemp -d)" || exit 9; g() { git -C "$w/d" -c user.name=r -c user.email=r@r -c commit.gpgsign=false "$@"; }; git init -q "$w/d" || exit 9; mkdir -p "$w/d/core" "$w/d/docs" "$w/d/templates" "$w/c" || exit 9; echo 1.0.0 > "$w/d/VERSION"; echo M > "$w/d/core/s.md"; echo t > "$w/d/core/subj.sh"; g add -A && g commit -qm base || exit 9; B="$(g rev-parse HEAD)"; echo p > "$w/d/docs/plan.md"; g add -A && g commit -qm "docs(plan): cross-reference PC-S870-DOCS-NAMED" || exit 9; echo t > "$w/d/templates/x.template"; g add -A && g commit -qm "fix: absorb PC-S871-TEMPLATE-NAMED" || exit 9; echo u > "$w/d/core/other.sh"; g add -A && g commit -qm "release: discharges PC-S872-CORE-MENTION by another route" || exit 9; T="$(g rev-parse HEAD)"; [ -z "$(g show --name-only --format= HEAD~2 | grep -E '^(core|templates)/')" ] || exit 9; g show --name-only --format= HEAD | grep -q '^core/other.sh$' || exit 9; g show --name-only --format= HEAD | grep -q 'subj.sh' && exit 9; printf -- '# l\n\n- **PC-S870-DOCS-NAMED** -- a.\n  verify: theirs_lacks core/s.md "ZZ"\n\n- **PC-S871-TEMPLATE-NAMED** -- b.\n  verify: theirs_lacks core/s.md "ZZ"\n\n- **PC-S872-CORE-MENTION** -- subject is core/subj.sh, which the naming commit never touches.\n  verify: theirs_lacks core/s.md "ZZ"\n' > "$w/c/l.md"; o="$(bash "$L" "$w/d" "$B" "$w/c" "$T" "$w/c/l.md" 2>/dev/null)"; k() { printf '%s\n' "$o" | awk -F'\t' -v l="$1" '$2==l && $1 ~ /^NAMED-UPSTREAM/ {print $1; exit}'; }; a="$(k PC-S870-DOCS-NAMED)"; b="$(k PC-S871-TEMPLATE-NAMED)"; c="$(k PC-S872-CORE-MENTION)"; [ -n "$b" ] && [ -n "$c" ] || exit 9; [ "$a" = NAMED-UPSTREAM-DOCS-ONLY ] && [ "$b" = NAMED-UPSTREAM ] || { echo "BL145-DOCS-ONLY-NAMING-READ-AS-ABSORPTION docs=${a:-<no row>} templates=$b" >&2; exit 1; }; [ "$c" = NAMED-UPSTREAM ] || exit 0; echo "BL145-CORE-TOUCHING-MENTION-STILL-NAMED-UPSTREAM (the third class: a commit that touches core/ but not the entry's subject)" >&2; exit 1



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

**Held note (batch 178):** one site converted on `b178-b1`, self-contained: `preclassify.sh`'s
`--untangle` manifest `ls-files` (`:453` above) now runs under `core.quotePath=false`. Its readers are
`map_consumer`, `blob_hash` and `file_hash`, all inside that loop; `preclassify-mode-bucket` U5 holds an
accented manifest file that must list once under its raw path, with a mutant restoring the default.
Every other site in the census is unchanged and the entry stays open.

verify: sh R=core/skills/ai-dlc-update/reconcile; [ -f "$R/lib.sh" ] || exit 9; set -- "$R"/*.sh; [ "$#" -ge 20 ] || exit 9; w="$(mktemp -d)" || exit 9; P='/^[[:blank:]]*#/ {next} /git -C "[^"]*"/ && (/ ls-(tree|files)[[:blank:]]/ || (/ diff[[:blank:]]/ && /--name-(only|status)/)) { if (/core[.]quotePath=false/ || / -z[[:blank:]]/) f++; else u++ } END {print u+0, f+0}'; printf '%s\n' 'x="$(git -C "$D" ls-tree -r --name-only "$T")"' 'git -C "$D" -c core.quotePath=false diff --name-only "$B" "$T"' '  # git -C "$D" ls-tree --name-only "$T"' 'echo "git ls-tree exited"' 'git -C "$D" diff -U0 "$B"' > "$w/p.sh" || exit 9; [ "$(awk "$P" "$w/p.sh")" = "1 1" ] || exit 9; o="$(awk "$P" "$@")" || exit 9; u="${o% *}"; f="${o#* }"; [ "$f" -ge 1 ] && [ "$((u + f))" -ge 20 ] || exit 9; [ "$u" -eq 0 ] && exit 0; echo "BL364-UNQUOTED-LISTING-SITES $u of $((u + f))" >&2; exit 1


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

## BL-378 — the suite-pole baseline still names `ledger-reverify` after the pole moved

**NOTE.** v0.665.0's 12-way gate reported the pole as `gate-adjudication-mutants` at 490s against a
baseline row for `ledger-reverify` at 628s (band 20%, ceiling 754s), with the note "a row pinned to
a unit that is no longer longest passes while watching the wrong number". Re-baseline
`docs/suite-pole-baseline.tsv` from a quiet 12-way run. The 6-way gates earlier in batch 173 skipped
this phase on the pool-width mismatch, because the operator's shell profile sets
`AI_DLC_FIXTURE_JOBS=6`.

verify: manual

## BL-402 — `apply.sh --finish` skips the resolution phases, so it stamps theirs over a tree whose DECISION remedy was never performed

**DEFECT. Found at batch 178 by the B3 builder and its tip adversary.** The residue `BL-336` left. That release pointed the provenance refile's did-not-run row at re-render, re-approve and apply instead of `--finish` (`reapply_remedy`, `core/skills/ai-dlc-update/reconcile/apply.sh:198-207`), but the finisher itself still accepts the tree. The `FINISH=0` span (`:532-1799`) holds the drift refile (`:947`) and the NOEXEC audit (`:1767`). Under `--finish` the only tree check is `finish_verify_tree` (`:1886`), which reads preclassify's pure-apply buckets and nothing else, so no DECISION row's remedy is re-checked; the withheld-stamp row at `:1981` still prints `apply.sh --finish` as the next step.

Measured in `apply-drift-refile`'s seeded world with the consumer schema at mode 000: apply raises `DECISION drift … did not run` and withholds the stamp, and `--finish` then stamps `version: 9.9.9` with `my-persona-skill` unrefiled and the schema still drifted. A control world whose refile was done by hand also stamps, so a finisher that refuses everything does not pass. **A correct fix must update `core/fixtures/apply-drift-refile/run.sh:434`** in the same change: it pins the defective behaviour as the r-M2 mutant's expected result.

Discharges no consumer candidate.

verify: sh S=core/fixtures/apply-drift-refile/seed.sh; A=core/skills/ai-dlc-update/reconcile/apply.sh; [ -f "$S" ] && [ -f "$A" ] || exit 9; T="$(mktemp -d)" || exit 9; w() { TMPDIR="$T" bash "$S" 2>/dev/null; }; G="$(w)" && [ -f "$G/env.sh" ] || exit 9; eval "$(sed 's/^/G_/' "$G/env.sh")"; bash "$A" "$G_DIST" "$G_BASE" "$G_CONSUMER" "$G_THEIRS" >/dev/null 2>&1; grep -q my-persona-skill "$G_EXT" 2>/dev/null && grep -qE '^version: 9\.9\.9$' "$G_STAMP" || exit 9; W="$(w)" && [ -f "$W/env.sh" ] || exit 9; eval "$(sed 's/^/W_/' "$W/env.sh")"; chmod 000 "$W_SCHEMA"; o="$(bash "$A" "$W_DIST" "$W_BASE" "$W_CONSUMER" "$W_THEIRS" 2>/dev/null)"; chmod 644 "$W_SCHEMA"; grep -q 'did not run' <<<"$o" || exit 9; grep -qE '^version: 9\.9\.9$' "$W_STAMP" && exit 9; H="$(w)" && [ -f "$H/env.sh" ] || exit 9; eval "$(sed 's/^/H_/' "$H/env.sh")"; chmod 000 "$H_SCHEMA"; bash "$A" "$H_DIST" "$H_BASE" "$H_CONSUMER" "$H_THEIRS" >/dev/null 2>&1; chmod 644 "$H_SCHEMA"; mkdir -p "$(dirname "$H_EXT")" && cp "$G_EXT" "$H_EXT" && git -C "$H_DIST" show "${H_THEIRS}:core/schemas/provenance-block.json" > "$H_SCHEMA" || exit 9; bash "$A" --finish "$H_DIST" "$H_BASE" "$H_CONSUMER" "$H_THEIRS" >/dev/null 2>&1; grep -qE '^version: 9\.9\.9$' "$H_STAMP" || exit 1; bash "$A" --finish "$W_DIST" "$W_BASE" "$W_CONSUMER" "$W_THEIRS" >/dev/null 2>&1; grep -qE '^version: 9\.9\.9$' "$W_STAMP" || exit 0; grep -q my-persona-skill "$W_EXT" 2>/dev/null && git -C "$W_DIST" show "${W_THEIRS}:core/schemas/provenance-block.json" | cmp -s - "$W_SCHEMA" && exit 0; exit 1

## BL-404 — the acknowledge hook's typed-invocation anchor depends on the harness's serialisation, and an updater call inside a pipeline session is asserted by no arm

**NOTE. Found at batch 178 by the S316 tip adversary.** `core/hooks/ai-dlc-acknowledge.sh:196` recognises a typed `/ai-dlc` or `/ai-dlc-update` only as `"role":"user","content":"<command-message>…</command-message>\n<command-name>/…`. Across the local transcripts all 301 typed-skill records carry that shape (negative control 0); the other user lines with a `<command-name>` are built-in commands with no `<command-message>`, and there are 0 array-content variants. If the harness changes how it serialises a typed command, typed updater sessions are denied writes under the pause again and Check 2z stops gating typed `/ai-dlc` sessions, and nothing in the tree would notice.

Second claim: the last-skill rule (`tail -1`) and the live `Skill` override (`:207-210`) mean a pipeline lead that calls `Skill(ai-dlc-update)` stops pausing writes until `/ai-dlc` is invoked again. Accepted by contract; `updater-session-signals` seeds only the reverse order (`run.sh:109-110`), so no arm asserts it.

Discharges no consumer candidate.

verify: manual

The receipt is manual because its subject is the harness's own transcript format, which no file in this tree contains: a predicate keyed on the hook's regex would only check the regex against the copy the seeds were written from.

## BL-406 — the `ledger-reverify` fixture is the suite's pole and is one serial unit; shard it

**DEFECT. Filed at batch 178 by the operator, who directs that the next batch takes it.** The pre-push
fixture suite is pole-bound: its makespan tracks its single longest directory, because the outer pool
globs `core/fixtures/*/run.sh`. `core/fixtures/ledger-reverify/run.sh` is that pole — 429s loaded in
`.git/ai-dlc-fixture-durations` (next: `gate-adjudication-mutants` 405s), 4447 lines that call the
engine 126 times in sequence with no internal parallelism, and `docs/suite-pole-baseline.tsv` still
records it at 628. No pool width can get under a single serial unit, so `AI_DLC_FIXTURE_JOBS` buys
nothing at the pole, and each release touching `ledger-reverify.sh` grows it (batch 178's B2 added
about 30 engine runs).

**Remedy shape, the pattern this repo already ships.** `fold-architect-ledger-join-mutants` and its
`-b`/`-c` siblings: a `SHARDS="a b c"` declaration in the fixture, one directory per shard that
re-enters the fixture with `--group <x>`, every shard paying the shared controls so none can pass
against a harness that never ran, and a join that refuses unless every part ran exactly once. The
shard count comes from a measured fixed cost per shard, not a preference. Two differences to design for:
- **This fixture SHIPS** (no `.dist-only`), so every shard directory ships too and needs the packaging
  `.claude/rules/fixture-ship-decl.md` names: `uninstall.sh`, both manifest copies, `setup-sites.md`,
  and I74's join.
- **Each new shard directory needs a read-set entry**, traced with the sandbox tracer per
  `operator-rulings.md`.

Re-measure the pole after the split, re-baseline `docs/suite-pole-baseline.tsv` (`BL-378`), and state
which unit became the new pole.

Discharges no consumer candidate.

verify: sh F=core/fixtures/ledger-reverify/run.sh; [ -f "$F" ] || exit 9; C="$(grep -v '^[[:blank:]]*#' "$F")"; [ -n "$C" ] || exit 9; G="$(sed -nE 's/^SHARDS="([a-z ]+)".*$/\1/p' <<<"$C" | tail -1)"; [ -n "$G" ] || exit 1; D="$(sed -nE 's/^lr_unit_([a-z0-9_]+)\(\) \{.*$/\1/p' <<<"$C" | sort)"; [ -n "$D" ] || exit 1; U=""; n=0; for g in $G; do n=$((n+1)); P="$(bash "$F" --plan "$g" 2>/dev/null)" || exit 1; [ -n "$P" ] || exit 1; U="$U$P"$'\n'; [ "$g" = a ] && continue; R="core/fixtures/ledger-reverify-$g/run.sh"; [ -f "$R" ] || exit 1; K="$(grep -v '^[[:blank:]]*#' "$R" | sed -E 's/[[:blank:]]+#.*$//')"; grep -qE "bash \"\\\$IMPL\" --group $g([[:blank:]]|\$)" <<<"$K" || exit 1; grep -qF "in shard '$g'" <<<"$K" || exit 1; grep -qE '^exec ' <<<"$K" && exit 1; done; U="$(printf '%s' "$U" | grep . | sort)"; [ -z "$(uniq -d <<<"$U")" ] || exit 1; [ "$U" = "$D" ] || exit 1; [ "$n" -ge 2 ]


## BL-409 — `predicate-differential.sh` cannot reach `docs/escalations/pending.md`, so the suppression-lifetime site reports UNDECIDABLE on every consumer

**NOTE. Found by the BL-129 hand at batch 179, not fixed there.** The suppression-lifetime site added to `predicate-sites.md` names `docs/escalations/pending.md` as its subject, and the reader only looks under `_bmad-output/`. Run directly on the reference consumer's `pending.md` over `1f838777~1..HEAD`, the block gives `OK` on both sides, so the block works once the reader can reach the file. The hand's scoring scripts are not committed; re-derive before building.

verify: manual -- no receipt has been scored against the reader; the claim is the BL-129 hand's report and is unverified by the lead.

## BL-410 — the provenance-block predicate site has no walk-up marker in its probe root, so a schema-only change reads STABLE without the comparison happening

**NOTE. Found by the BL-129 hand at batch 179, not fixed there.** The materialized `validate-provenance-block.sh` resolves `SCHEMA=<consumer>/.claude/schemas/provenance-block.json`, the consumer's installed schema, on both sides of the differential, so the v0.382.0 case the site exists to catch (a schema-only change) reports STABLE. `predicate-reclassification` Part 10 cannot see it because its seed creates no `.claude/schemas/`. Re-derive before building; the claim is the hand's report.

verify: manual -- no receipt has been scored; the claim is the BL-129 hand's report and is unverified by the lead.

## BL-411 — three callers turn the reconcile memo's refusal (125) into a clean result

**DEFECT. Found by the `b179-lib` tip adversary at batch 179, predating that branch.** `memo_ls_tree` and `memo_show` return 125 when a cached status is unreadable or malformed (BL-403(d)), and three callers swallow it: `retired-layer-token.sh` `files_at` (`memo_ls_tree … || return 0`) and `show_at` (`memo_show … || true`), and `layer-drift.sh` (`_tree="$(memo_ls_tree … | grep '^core/' || true)"`, near `:1409`). Measured with an empty `.s` on a cache hit: `rc=0 matches=0` on base and on the branch, against `matches=2` uncorrupted. The branch changed one thing here: base's swallow left `numeric argument required` on stderr and the branch's leaves nothing, so the refusal got quieter. Fourteen `git_show` call sites in `layer-drift.sh` and ten in `unregistered-drift.sh` are further candidates, listed and not traced. Re-derive before building.

verify: manual -- no receipt has been scored; the claim is the adversary's report and the lead has not re-derived it.
