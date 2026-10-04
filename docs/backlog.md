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

**BATCH 191 (0.721.0): A LOSS CANARY BESIDE THE DROP-NOTICE GUARD, AND `EMS_POOL_WIDTH=1` ON
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
  exercises both sides. The adversary's "scoped 0/0" did NOT reproduce on the 8x1500 burst: 0 of
  8 scoped attempts traced clean, at 1-minute load 8.3 to 26.8, and two standalone attempts gave
  31 and 33 notices with 218 and 152 canary paths. The scoped side therefore traces its own small
  burst, 1 reader over 100 files, and the unscoped side keeps 8x1500. With that split the arm RAN
  rather than skipped, one run at 1-minute load 3.2: unscoped attempt 1 was forced, a scoped
  attempt was clean, and the guard-deleted mutant was killed. One sample; the stub-world arm is
  still the proof that runs everywhere.
- **`--tracer both` canary arm.** The stub world's empty-stream run must name
  `LOSS CANARY: 2 path(s)` in its UNCOMPARED reason. A mutant scoping the canary back to
  `--tracer sandbox` loses the token.
- **Width arms.** These now require `ems=1` beside `width=1` under both `--tracer sandbox` and
  `--tracer both`. The four width mutants are re-anchored on the two-knob line.
  `core/fixtures/enforcement-map-sites` shard a now drives its own knob through `--print-width`.
  The cells are: unset 8, 1, 64; and 0, `abc`, 65 and a 20-digit value each exit 2. The dead
  `''` case is gone.
- **Unreadable canary arm.** `readset_loss_canary` now sits between `READSET_CANARY_BEGIN`/`END`.
  Called on a missing stream set, it must print `unreadable`, and the deriver's guard must turn
  that into an omission. Two wrong builds each read `0` and are killed: `unreadable` replaced by
  `0`, and comm's status discarded.
- **A one-fixture `--list` whose fixture is omitted now writes the map.** Under `--list`, the
  "mapped > 0" control reads the MERGED map's fixture count. So the omission is recorded, and that
  fixture's stale rows are dropped instead of surviving an exit-1 run. The arm seeds a stale row
  and requires it gone, the other fixtures' rows kept, and the OMITTED header written. The mutant
  restores the traced-count control and leaves the stale row in place.
- **The unread control the header always cited now exists.** `.git/readset-unread-control` is
  planted after the copy and reset with every other file. A fixture whose window moved its atime
  is OMITTED naming it. The arm reads it from a probe fixture, and the guard-deleted mutant maps
  that fixture. Before planting it in `.git/`, the census was checked: 0 of 33 fixtures read
  `.git/description`, against 2 reading `.git/HEAD`.

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
- a peak 1-minute load of at least 4.5 during the trace;
- each fixture's path set outside `.git/**` identical across the three traces. Batch 192 added
  this arm. The fixtures' reads are deterministic, so any disagreement between traces is loss.
  It catches lost reports on paths that do not exist, which neither the drop notice nor the
  canary can see.

The loss canary replaces the "completeness control" the batch-189 contract asked for, with the
limits stated above.

**BATCH-191 STAGE-1 TRACE, AT 0.721.0 (`3efb87d8`): NOT MET, AND THE TRACE ITSELF RAISES THE LOAD.**
Three consecutive five-fixture `--list` runs, main checkout detached, map restored after each,
nothing committed. Each started quiet (1-minute load 4.5, 3.4 and 11.3) and peaked at 20.8, 42.9
and 36.9, so the traced fixtures make their own load. Run 1 mapped 4 of 5 (`enforcement-map-sites`
OMITTED, 13 drop notices). Run 2 mapped 1 of 5: `-b`, `-c`, `validator-arm-selection` and
`validator-arm-selection-b` were OMITTED with 284, 49, 62 and 3. Run 3 mapped 3 of 5
(`enforcement-map-sites` 2, `validator-arm-selection-b` 23). Every omission was a drop notice; the
canary and the unread control never fired.

**TWO CLEAN TRACES OF ONE FIXTURE DISAGREE, WITH NO SIGNAL.** `enforcement-map-sites-b` and `-c`
traced clean in runs 1 and 3 with identical 960-path sets. `validator-arm-selection` traced clean
in both, 1569 paths against 1548: beyond `.git/**` rows and sha-prefixed argv rows, run 1 holds 19
`core/fixtures/<name>/seed.sh` paths that run 3 lacks. Run 3 carried no drop notice, no canary and
no unread-control firing for that fixture. So either its reads are not deterministic across runs,
or a loss occurred that neither guard sees. Which is open. A single clean trace of
`validator-arm-selection` is not evidence of a complete read set.

**BATCH 192: THE STREAM LOST THE REPORTS; THE READS ARE DETERMINISTIC.** Run 3 had lost
reports for paths that do not exist on disk, and neither guard can see that class.
- **The reads.** Three untraced reps of `validator-arm-selection` were launched exactly as the
  deriver launches it, without `sandbox-exec`, at `1047e971` and load 2.5-3.3. Each rep exited 0
  with 12 ok, and each read 784 atime paths and 97 `seed.sh`. Outside `.git/**` the three sets
  are byte-identical (one md5), and they match run 3's own `.at` file. The 13+13 differences per
  pair are all loose objects under `.git/objects/**` that the run creates.
- **The atime controls.** A file read appeared in the scan and an unread file did not, in the
  same invocation, and every reset scanned 0.
- **What run 3 lost.** The 19 rows are `core/fixtures/<name>/seed.sh` for fixture directories
  that carry NO `seed.sh`: 232 directories against 97 files. They come from bash expanding the
  glob at `scripts/validate-enforcement-map.sh:3251`, which issues a `file-test-existence` on
  every directory. Run 3's window reported 116 of the 135 absent paths and every one of the 97
  present ones, with 0 drop notices in 635,078 lines.
- **Why neither guard fired.** A path with no file has no atime, so `readset_loss_canary` cannot
  see it by construction. The deriver's own header says so ("a lost stat, a lost negative
  lookup ... are all invisible to it").
- **The quiet-box control.** One sandboxed expansion of that glob at load about 3 reported 153,
  232 and 219 of 232 paths over three reps, with 0 notices each time. So the report channel
  loses negative lookups silently even when the box is idle. This control cannot separate a
  drop in `log stream` from the kernel never emitting the report.
- **Population.** The committed map carries 2390 non-`.git` rows naming a path absent at
  `1047e971`. That set is negative lookups at trace time plus files deleted since: 671 distinct
  paths across 129 of 230 mapped fixtures. `validator-arm-selection`
  carries 311 of them, 126 of which are `seed.sh`. Every sandbox-traced row set in that map is a
  FLOOR for this class.
- **Consequence: a NOTE, because the runner already covers this class.** When a file appears,
  the runner adds its parent directory to the match set (`.githooks/pre-push:697-699`). Driving
  the runner's selection (`.githooks/pre-push:737-755`) over the committed map for three of the
  19: `plan-rotate`, whose directory row `validator-arm-selection` carries, selects it, while
  `ledger-reverify-b` and `story-evidence-scaffold` select 3-4 other fixtures and not that one.
  The reason is that `validator-arm-selection`'s rows lack BOTH the `seed.sh` row and the
  directory row for those two. Its rows last moved on 2026-09-30, and 10 fixture directories
  were born after that (`ledger-reverify-b` on 2026-10-01). That is map age, which the runner
  already prints, and not stream loss. None of the 19 is orphaned: each path is still carried by
  at least one other fixture. The validator itself also runs unconditionally as its own gate
  phase (`.githooks/pre-push:124-125`) over the live tree. So a lost absent-path row costs
  nothing while its directory row survives.
  Measured on run 3's own stream set: 232 of 232 `core/fixtures/<name>` directory rows survived
  beside 213 of 232 `seed.sh` rows, in the same window with 0 notices (impossible-name control 0).
- **Not built, and why.** The lever would be a deriver change: drop `file-test-existence`
  reports for paths that do not exist when the window closes. Dropping those rows shrinks the
  runner's `.universe`, so a path that later appears and is named by no surviving row becomes an
  orphan and forces a full run. 998 of the 2390 rows are `.dist-only`. That is a runner-behaviour
  change across about 2400 rows, so it needs a contract pass and an adversary, which makes it a
  release and not a batch tail. Until then, the identical-sets arm in the revised close criterion
  is what catches this loss.

verify: sh D=core/scripts/derive-fixture-readsets.sh; [ -f "$D" ] || exit 9; B="$(grep -v '^[[:space:]]*#' "$D")"; grep -q 'sandbox-exec -f' <<<"$B" || exit 1; grep -q 'fs_usage -w' <<<"$B" && exit 1; grep -qF '"$(id -u)" = "0"' <<<"$B" && exit 1; exit 0

**BATCH-189 BEFORE/AFTER TRACE, ONE SAMPLE PER SIDE.** `bash core/scripts/derive-fixture-readsets.sh --list "validator-arm-selection-b enforcement-map-sites" --tracer sandbox`, main checkout detached at each sha in turn, map restored and nothing committed. Base `9bbc5a50` (load 4.52): `validator-arm-selection-b` OMITTED with 108 drop notices, `enforcement-map-sites` OMITTED with 894. Tip `946fb8ce`, carrying the BL-436 cwd fix (load 11.46): `validator-arm-selection-b` CLEAN, `enforcement-map-sites` OMITTED with 1036. Lever (a) moved the fixture it was predicted to move, at the higher load; one sample per side is not a close. `enforcement-map-sites` still drops on its seed `cp -R` burst, where no copy form was shown to help. Stage 1 and the three-consecutive-clean-traces criterion with a completeness control stand.

