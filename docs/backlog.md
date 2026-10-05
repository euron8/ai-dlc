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
- ~~Establish whether the runner's content-key skip reads the `.git/**` rows.~~ Answered at batch
  193: it does not. Both hooks strip `^\.git/` and `^\.git$` from the manifest and the universe
  before any selection (`.githooks/pre-push:577`, `:737`; the same two lines in
  `core/git-hooks/pre-push`), and `scripts/suite-content-key.sh` never names the map (0 mentions,
  against 3 in `.githooks/pre-push`). The sandbox tracer's missing `.git/**` rows cost the runner
  nothing.
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
- each fixture's path set outside `.git/**`, filtered to the paths that EXIST in the traced tree
  at window close (`[ -e "$TREE/$p" ] || [ -L "$TREE/$p" ]`), identical across the three traces.
  Batch 192 added this arm unfiltered. Batch 193 filtered it, by operator ruling: the stream
  loses negative-lookup reports silently even on an idle box, so an unfiltered comparison is
  unreachable by construction, and every disagreement it reports is the class batch 192 tiered
  a NOTE. The filter is applied to the COMPARISON only. The deriver's written map keeps absent
  rows, because `derive-fixture-readsets.sh` holds a negative lookup on a real name to be a
  dependency and `core/fixtures/readset-skip`'s `existonly` mutant kills a deriver that drops
  them. What the filter acquits is a lost absent-path row. That is safe only where the fixture
  also carries the path's parent-directory row, which the runner's ride-along
  (`.githooks/pre-push:697-699`) selects on. Measured at `d4354b7c`: 2 rows across the five
  subjects lack that cover, both malformed-path lookups in `validator-arm-selection`
  (`core/core/skills/ai-dlc`, `core/scripts/core/skills/ai-dlc`).

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

**BATCH 193 STAGE-1 TRACE, AT `d4354b7c`: NOT MET, BUT THE FILTERED ARM IS NOW SATISFIABLE.** Three consecutive five-fixture `--list` runs under `--tracer sandbox`, main checkout, map restored after each, porcelain 0 after each. Every omission was a drop notice; the canary and the unread control never fired.

| run | start / peak 1-min load | mapped | OMITTED (drop notices) |
|---|---|---|---|
| 1 | about 8 / 32.0 | 0 of 5 | `enforcement-map-sites` 1015, `-b` 340, `-c` 33, `validator-arm-selection` 159, `validator-arm-selection-b` 579 |
| 2 | 8.6 / 12.8 | 2 of 5 | `enforcement-map-sites` 208, `-b` 43, `-c` 18 |
| 3 | 3.1 / 5.9 | 4 of 5 | `enforcement-map-sites` 238 |

The filtered identical-sets arm was run over the pairs that traced clean twice (runs 2 and 3). It used a self-probe first: an absent-only difference compares equal and a lost present path compares unequal.
- `validator-arm-selection`: filtered 992 against 992, 0 differences. Raw, 1373 against 1369 with 58 differences. All 58 name paths absent from the traced tree: `core/fixtures/<x>/seed.sh` lookups and `<sha>:<path>` argv rows. The unfiltered arm would have failed this pair on loss the filter is ruled to acquit.
- `validator-arm-selection-b`: 960 against 960, identical both filtered and raw.

`enforcement-map-sites` dropped in all three runs, at every load, and is now the stage-1 blocker alone. The other four have each traced clean at least once in this batch.

**Batch 193 correction to the `cp -R` prose above.** The seed has copied with `cp -RX` since 0.721.0 (`3efb87d8`, `core/fixtures/enforcement-map-sites/seed.sh:38-45`), so "no form ships" and "its seed `cp -R` burst" describe the tree before that release. The batch-191 stage-1 trace was taken at `3efb87d8` itself, so its drop counts already include the `cp -RX` change.

**Batch 194: the `enforcement-map-sites` stream is cut inside the fixture, in 0.723.0. The stage-1 trace is owed after the merge.** Batch 193's three windows put about four-fifths of this fixture's traced stream in two places. The first was about 45 heavy `grep` processes per run reading the LIVE tree, about 100k reports, which came from the A40 cwd battery's mutants. The second was every `--run-one` cell re-running `seed.sh`, about 90k reports. Later seeds read 0 paths the first did not read. Batch 189 measured the copy FORM and never the copy COUNT or the battery's cwd, so this is not a refuted lever.
- R1: the shard driver seeds ONE template above the control `--run-one`. Each cell receives it as its 4th argument and copies it into a fresh root. A missing or empty template, or one without the validator, exits 2. The template is hashed by count and by (path, md5) before and after the pool, and the hash must be taken over the directory the cells received.
- R2: C2, C4 and `cwd_full_bit` run from a DECOY: the template plus the distribution's `VERSION` and `git init`, passed as a 5th argument. The decoy carries the markers a walk-up regression keys on, so the BL-436 class stays caught. A `VERSION` walk-up mutant fails 3 at base and at tip. The cells keep the template with no `VERSION`.
- New arms: A1 requires M1's decoy run to reproduce the BL-436 false clean (I91, I94, I81), and I95's seeded finding to be named. A self-probe runs the same predicate from an empty cwd, and it must fire. A static arm requires exactly one `seed.sh` call site.
- Builder evidence: 44 of 44 cells are byte-identical to base, stdout and rc. Assertion counts are 48/36/39, unchanged. The fork total is 3192 of 3196. Shard a ran about 30s faster across two interleaved reps at load 18-24.
- The entry stays LIVE whatever the trace shows. Stage 1 met advances it to stage 2 (the operator's `--tracer both` run). The expected moved map rows are ZERO. Drops caused by load, like run 1's 680 notices at load 32, are outside this fix.

**BATCH 194 STAGE-1 TRACE AT `3868b252` (0.723.0): NOT MET, BUT `enforcement-map-sites` NOW TRACES CLEAN.** Three consecutive five-fixture `--list` runs under `--tracer sandbox`, from the main checkout detached at the merged sha. The map was restored after each run and none was committed.

| run | 1-minute load at start | OMITTED |
|---|---|---|
| 1 | 2.5 (falling from 18) | `enforcement-map-sites-b` (loss canary, 10 paths), `validator-arm-selection` (28 drops), `validator-arm-selection-b` (326 drops) |
| 2 | 4.7 | `validator-arm-selection-b` (203 drops, plus a loss canary of 7 paths) |
| 3 | 8.4 | `enforcement-map-sites-c` (10 drops) |

- `enforcement-map-sites` mapped in all 3 runs. Batch 193 had it omitted in all 3. The stage-1 blocker is now spread across the other four fixtures and does not follow any one of them.
- **The prediction of ZERO moved rows was WRONG.** Each clean `enforcement-map-sites` shard gains about 127 rows and loses 24 against the committed map. Runs 2 and 3 agree byte-for-byte on that fixture (0 differences). The gained rows are mostly `core/fixtures/**`, plus `VERSION` (the decoy copies it) and `scripts/plan-rotate.sh`. The 24 lost rows are 8 `.git/objects` rows plus scattered `core/` rows, one of them `core/.DS_Store`. The committed rows are the likelier stale side: all three shards carry an identical 858, from a fixture that had never traced clean. The two-trace agreement is evidence for that, not proof.
- **One pseudo-path passes `BL-439`'s filter:** `--exclude-dir=fixtures` became a map row for `enforcement-map-sites` (1 in run 3's map, 0 in the committed map). It is a `grep` option read as a path. NOTE.

## BL-441 — `derive-fixture-readsets.sh --all` built its fixture list newline-separated, so one OMITTED fixture discarded every good trace and the plan-shape controls never ran under `--all`

**DEFECT.** Filed by the consumer as `PC-S316-DERIVE-READSETS-ALL-REFUSES-TO-WRITE-THE-WHOLE-MAP-WHEN-ONE-FIXTURE-IS-OMITTED`. At base `f8384eea`, the `--all` branch of `core/scripts/derive-fixture-readsets.sh:640` built `LIST` from a `for` loop that printed one name per line. Every membership test on that list is `case " $LIST " in *" $f "*)`, which needs a space on both sides of each name, so none of them could match a newline-separated list. `--list` was always space-separated and always correct, which is why nothing looked broken.

**Three distinct claims, each scored:**
- **The untraced-fixture guard at base `:1084`** classed every fixture as untouched under `--all`. The loss check below it then died `merge dropped '<f>'` on any OMITTED fixture and discarded every good trace in the run. This is the consumer's claim. LIVE at base, and fixed.
- **A second site at base `:997`**: the plan-shape selectivity controls at `:998-1009` were skipped on every `--all` run, because `case " $LIST " in *" plan-shape "*)` never matched. They could not fire. The consumer did not file this site. LIVE at base, and fixed.
- **Making `:997` reachable opens a new failure mode.** The plan-shape pair greps this run's traced rows in `$WORK/map`. Once `:997` can match, an OMITTED plan-shape fails the positive control, and the run dies `controls failed; the map was NOT written`. That is the same defect again, reached through one fixture. The contract adversary raised it as amendment D1, and the fix guards it.

**The fix as landed** (`9ff191fe`; line numbers are on the release tip):
- `readset_all_list <fixtures-dir>`, between `# READSET_ALLLIST_BEGIN/END` at `:306-330`, prints the basenames of directories that hold a `run.sh`, space-separated on one line. The `--all` branch calls it at `:701`.
- `readset_untraced_lost <old-map> <merged> <traced-list>`, between `# READSET_UNTRACED_BEGIN/END` at `:332-365`, normalises its list argument (space or newline) and tests membership by exact name on both the traced list and the merged map. It prints each lost fixture, one per line, and returns 2 when the merged map cannot be read. The caller at `:1151-1158` stages that output to a file, refuses on a non-zero status, and dies with the existing `merge dropped` message when the output is non-empty.
- **The D1 OMITTED guard** at `:1064-1068`: the plan-shape pair runs only when plan-shape has rows in `$WORK/map`. Otherwise the run prints `  SKIP  plan-shape controls: plan-shape OMITTED this run` and the fixture stays unmapped, so it runs on every push. This follows the `--list` carve-out beside it.
- `readset_merge_map` keeps its own newline normalisation. The comment at `:1131-1136` no longer claims that no stale map fixture exists, because `notify-hook-channel` has rows in the committed map and no directory.
- `core/fixtures/readset-skip/run.sh` drives both sentinel functions, scans both new spans as call sites, and runs an end-to-end `--all --tracer sandbox` arm in the stub world (`d52af4c6`). On the release tip it reads `readset-skip: PASS (157 assertions)`.

**Wrong fixes rejected, each scored 1 by the receipt below:**
- Inlining a `tr` at the `:1084` guard only (W2). `:997` stays unreachable and the sentinels do not exist.
- Gutting the loss guard so it reports nothing (W1). A `--list` merge that loses an untraced fixture must still die.
- A tab-joined all-list, and an all-list that keeps directories with no `run.sh`.
- Substring membership in `readset_untraced_lost` (`index(traced, $1)`). With `fx-b` traced, it counts `fx` as traced too.
- Dropping the list normalisation inside `readset_untraced_lost`.
- Making `:997` reachable without the D1 guard.
- A D1 guard that greps `^plan-shape` without the tab. A mapped `plan-shape-x` sibling's rows then count as plan-shape's, and the pair runs on an omitted plan-shape. The receipt's omitted-plan-shape map carries that sibling, and `readset-skip`'s world S carries a `plan-shape-x` fixture, whose `notab` mutant dies `controls failed`.
- `readset_untraced_lost` reading the caller's `$MAP` in place of its first argument. Under the receipt's `set -u`, `$MAP` is unbound inside the extracted function, which aborts and prints nothing, so m2 and m3 fail. That rejection comes from the receipt's harness, not from behaviour. The discriminating kill is world O in `readset-skip`, which runs the whole deriver with `$MAP` bound.

Exempting `$OMITTED` members from the untouched loop (W3) and normalising only inside `readset_merge_map` (W4) leave the tree at base for this receipt: W4 changes nothing, and W3 creates neither sentinel. Both therefore read 1, as base does.

**Receipt.** It extracts both sentinel blocks and the `:1064` plan-shape span from the deriver and drives them on seeded inputs. `readset_all_list` runs on `aa`, `mid`, `zz` and `nope`, where only `nope` lacks a `run.sh`. The receipt asserts space-delimited membership of every member, including the middle one, that `nope` is absent, and that the command-substitution value carries no newline or tab. `readset_untraced_lost` runs three cases on a newline-separated traced list whose omitted fixture is not first. In m1 the omitted fixture is absent from the merged map and the output is empty. In m2 the untouched fixture is lost and the output is exactly `untouched`. In m3, `fx-b` is traced, `fx` and `fx-b` are both in the old map, the merged map lacks `fx`, and the output is exactly `fx`. Finally, the plan-shape span must print its PASS line when plan-shape has rows and its SKIP line when it has none, with `FAIL=0` both times. The map with no plan-shape rows still carries a `plan-shape-x` row. Scored under `bash -c 'set -uo pipefail; …'` from the repo root: release tip 0; base 1; the two sibling fixes alone 1; each of the nine wrong fixes above 1; a cwd with no deriver 9.

verify: sh D=core/scripts/derive-fixture-readsets.sh; [ -f "$D" ] || exit 9; w="$(mktemp -d)" || exit 9; F="$w/fx"; mkdir -p "$F/aa" "$F/mid" "$F/zz" "$F/nope" "$w/psin" "$w/psom" || exit 9; for n in aa mid zz; do echo : > "$F/$n/run.sh"; done; echo n > "$F/nope/notes.md"; [ -f "$F/mid/run.sh" ] && [ ! -f "$F/nope/run.sh" ] || exit 9; T="$(printf '\t')"; NL="$(printf '\nx')"; NL="${NL%x}"; printf '# readsets\nkept%ssrc/a\nomit%ssrc/b\nuntouched%ssrc/c\n' "$T" "$T" "$T" > "$w/o12"; printf 'fx%ssrc/d\nfx-b%ssrc/e\n' "$T" "$T" > "$w/o3"; printf 'kept%ssrc/a\nuntouched%ssrc/c\n' "$T" "$T" > "$w/m1"; printf 'kept%ssrc/a\n' "$T" > "$w/m2"; printf 'fx-b%ssrc/e\n' "$T" > "$w/m3"; printf 'plan-shape%sscripts/validate-plan-shape.sh\nkept%ssrc/a\n' "$T" "$T" > "$w/psin/map"; printf 'kept%ssrc/a\nplan-shape-x%score/fixtures/plan-shape-x/run.sh\n' "$T" "$T" > "$w/psom/map"; [ -s "$w/m3" ] && [ -s "$w/psom/map" ] || exit 9; sed -n '/^# READSET_ALLLIST_BEGIN$/,/^# READSET_ALLLIST_END$/p' "$D" > "$w/al.sh"; sed -n '/^# READSET_UNTRACED_BEGIN$/,/^# READSET_UNTRACED_END$/p' "$D" > "$w/ul.sh"; sed -n '/^case " \$LIST " in \*" plan-shape "\*)/,/^# UNDER /p' "$D" > "$w/ps.sh"; f=0; bad() { echo "BL-441: $1" >&2; f=1; }; v="$( . "$w/al.sh" >/dev/null 2>&1; readset_all_list "$F" 2>/dev/null )"; for n in aa mid zz; do case " $v " in *" $n "*) ;; *) bad "--all list lacks space-delimited $n: [$v]" ;; esac; done; case " $v " in *" nope "*) bad "--all list names a directory with no run.sh" ;; esac; case "$v" in *"$NL"*|*"$T"*) bad "--all list is not space-joined" ;; esac; u() { ( . "$w/ul.sh" >/dev/null 2>&1; readset_untraced_lost "$1" "$2" "$3" ) 2>/dev/null; }; r="$(u "$w/o12" "$w/m1" "kept${NL}omit")"; [ -z "$r" ] || bad "m1: traced-but-omitted fixture reported lost: [$r]"; r="$(u "$w/o12" "$w/m2" "kept${NL}omit")"; [ "$r" = untouched ] || bad "m2: lost untraced fixture not reported: [$r]"; r="$(u "$w/o3" "$w/m3" "fx-b")"; [ "$r" = fx ] || bad "m3: fx counted as traced by substring: [$r]"; ps() { ( WORK="$w/$1"; LIST="kept plan-shape"; FAIL=0; unset FIXTURE_HAS_PLAN_SHAPE; . "$w/ps.sh" 2>&1; echo "FAIL=$FAIL" ); }; r="$(ps psin)"; case "$r" in *"PASS  plan-shape's read-set names its own subject"*"FAIL=0"*) ;; *) bad "plan-shape controls did not pass on a traced plan-shape" ;; esac; r="$(ps psom)"; case "$r" in *"SKIP  plan-shape controls: plan-shape OMITTED this run"*"FAIL=0"*) ;; *) bad "an OMITTED plan-shape fails the controls instead of SKIPping" ;; esac; exit $f

## BL-442 — `story-provenance`'s schema-mutant arm ran its writer unpinned, so the mutant had no effect wherever TMPDIR had no marked ancestor, and the arm was green here by accident

**DEFECT.** Filed by the consumer as `PC-S316-STORY-PROVENANCE-FIXTURE-FAILS-ITS-SCHEMA-MUTANT-ARM-ONLY-UNDER-THE-READSET-TRACER`. The consumer saw the arm fail only under the read-set tracer. That symptom is real, and the defect is not specific to the tracer.

**Root cause.** Under its root-run tracers the deriver starts each fixture through `sudo -n -u` (`core/scripts/derive-fixture-readsets.sh:668`, `:873`). That invocation does not carry `TMPDIR`, and the receipt's `-u TMPDIR` leg models the result. The fixture's seed then roots under `/tmp`. At base, arm 18's `mut_run` (`core/fixtures/story-provenance/run.sh:198-202`) invoked the copied writer with no `AI_DLC_PROJECT_ROOT`. The writer resolves its root in this order (`core/scripts/stamp-story-provenance.sh:126-129`): the override, a walk up from the script's own directory, `CLAUDE_PROJECT_DIR`, then a walk up from the cwd. Under `/tmp` the script-dir walk finds no marker and `CLAUDE_PROJECT_DIR` is unset, so the cwd walk finds the repo. Schema lookup is root-first (`:152-156`, BL-302), so the writer loaded the REAL schema and the mutant had no effect. Reproduced with no tracer: `env -u TMPDIR bash core/fixtures/story-provenance/run.sh` reads `55 assertions, 1 failing` at base. From cwd `/` with `TMPDIR` unset, the same arm fails for a related reason. There is no cwd walk to the repo there, so the unpinned writer resolves no root at all, and the arm's own control dies with `FIXTURE BROKEN: control run does not refuse`.

**Normal green was an accident.** This machine's `TMPDIR` is `/var/folders/qr/v63hkc2n6s16yk44l131v9700000gn/T/`, and its parent holds a stray `.claude/` directory, which the writer's walk accepts as a root marker. The walk from the mutant copy stopped there. That marker holds only a `logs/` directory and no schema, so the copy fell through to its script-relative candidate, which is the mutant. On a machine without that stray marker, the arm fails on every run.

**The fix as landed** (`7ceb0cdd`; line numbers are on the release tip):
- `mut_writer` at `run.sh:192-194` is the one spelling of the mutant writer's invocation, and it pins `AI_DLC_PROJECT_ROOT="$MUTROOT"`, matching the later arms. `mut_run` and the precondition both call it.
- `MUTROOT` now sits under a decoy root that the fixture builds itself (`:189-190`). The decoy is `$ROOT/decoy` and carries a `.git` marker plus a copy of the schema. So every unpinned walk from the copy stops at the decoy, whatever `TMPDIR` is.
- The precondition comes after the schema copy, at `:216-250`, as three arms. P1: the pinned writer's `--print-schema` is MUTROOT's schema, compared by identity (`-ef`). P2: the same call from `/` with `TMPDIR` unset. P3: the copy, unpinned, from inside the decoy resolves the decoy's schema, which proves P1 can fail. If any of the three fails, the mutation arm stands down and the fixture reports `FIXTURE BROKEN: mutant writer resolves <path>` once. The tally goes from 55 assertions at base to 58.

**Wrong fixes rejected:**
- **Pinning `CLAUDE_PROJECT_DIR="$MUTROOT"` instead.** It reads green in four of the five legs below. It fails the decoy leg, because the writer's script-dir walk (`:127`) runs before `CLAUDE_PROJECT_DIR` (`:128`), finds the decoy's `.git`, and loads the decoy's `core/schemas/` copy. Scored 1.
- **SKIPping the arm when the mutant has no effect.** It reads ` 0 failing` in three legs while dropping to 54 assertions. The assertion floor of 56 and the required presence line kill it. Scored 1.
- **Reordering the writer's schema lookup script-first.** This reverts BL-302 and fails other arms in every leg. Scored 1.
- **Pinning `mut_run` alone, with no precondition arm.** It passes every leg at 55 assertions, so only the floor rejects it. Scored 1.
- **Preserving `TMPDIR` through sudo in the deriver.** The fixture would still depend on its environment. This was not built, because `TMPDIR` unset is already a leg of the receipt and does not route through the deriver.

**Receipt.** It runs the fixture five times, each with `AI_DLC_PROJECT_ROOT` and `CLAUDE_PROJECT_DIR` unset: under the ambient `TMPDIR`; under a fresh `mktemp -d /tmp/spfresh.XXXXXX`; with `-u TMPDIR`; from cwd `/` with `-u TMPDIR`; and with `TMPDIR` under a decoy tree carrying `.git` and `core/schemas/provenance-block.json`. The fresh `TMPDIR` is built under `/tmp` and not under the ambient `TMPDIR`, because the ambient one has the marked ancestor that hides the defect. The receipt exits 9 if any ancestor of that fresh directory carries one of the writer's root markers. Each leg needs rc 0, a tally of ` 0 failing`, at least 56 assertions, and the line `ok    mutation: dropping verdict from the profile disarms the guard`. Scored under `bash -c 'set -uo pipefail; …'` from the repo root: release tip 0; base 1, failing four legs at 55/1 with the ambient leg passing at 55; the two sibling fixes alone 1; each of the four wrong fixes above 1; a cwd with no fixture 9.

verify: sh F=core/fixtures/story-provenance/run.sh; S=core/schemas/provenance-block.json; [ -f "$F" ] && [ -f "$S" ] || exit 9; R="$(pwd)"; w="$(mktemp -d)" || exit 9; fr="$(mktemp -d /tmp/spfresh.XXXXXX)" || exit 9; dc="$(mktemp -d /tmp/spdecoy.XXXXXX)" || exit 9; mkdir -p "$dc/.git" "$dc/core/schemas" "$dc/t" && cp "$S" "$dc/core/schemas/" || exit 9; d="$(dirname "$fr")"; while [ "$d" != / ]; do { [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; } && exit 9; d="$(dirname "$d")"; done; f=0; L() { n="$1"; c="$2"; shift 2; ( cd "$c" && "$@" ) > "$w/$n.out" 2>&1 </dev/null; rc=$?; t="$(sed -n 's/^ *---- \([0-9][0-9]*\) assertions, \([0-9][0-9]*\) failing ----$/\1 \2/p' "$w/$n.out")"; a="${t% *}"; x="${t#* }"; if [ "$rc" -eq 0 ] && [ -n "$t" ] && [ "$x" = 0 ] && [ "$a" -ge 56 ] && grep -qF 'ok    mutation: dropping verdict from the profile disarms the guard' "$w/$n.out"; then :; else echo "BL-442 leg $n: rc=$rc tally=[$t]" >&2; f=1; fi; }; L ambient "$R" env -u AI_DLC_PROJECT_ROOT -u CLAUDE_PROJECT_DIR bash "$R/$F"; L fresh "$R" env -u AI_DLC_PROJECT_ROOT -u CLAUDE_PROJECT_DIR TMPDIR="$fr" bash "$R/$F"; L unset "$R" env -u AI_DLC_PROJECT_ROOT -u CLAUDE_PROJECT_DIR -u TMPDIR bash "$R/$F"; L root / env -u AI_DLC_PROJECT_ROOT -u CLAUDE_PROJECT_DIR -u TMPDIR bash "$R/$F"; L decoy "$R" env -u AI_DLC_PROJECT_ROOT -u CLAUDE_PROJECT_DIR TMPDIR="$dc/t" bash "$R/$F"; exit $f

## BL-443 — flat `_bmad-output/` pipeline state files the map names no reader for forced the whole fixture suite; keying selection on the pushed range is refused

**NOTE.** It affects wall clock only, and no gate verdict was ever wrong. Filed by the consumer as `PC-S316-PRE-PUSH-READSET-KEYS-ON-THE-WORKING-TREE-NOT-THE-PUSHED-RANGE`. The entry makes two claims, and they are dispositioned differently.

**Claim A, that selection keys on the working tree rather than the pushed range, is REFUSED as design.** `core/git-hooks/pre-push:602` builds `.changed` with `comm -3` of the verified record against `.now`, and `readset_manifest` hashes the working tree. That is deliberate, because fixtures read the working tree, not the pushed commits. Range keying would skip an uncommitted edit to a file a fixture reads, and it would lose every commit an earlier push sent with `--no-verify`, because those commits were never verified and are not in the range. The consumer's option (a) is therefore not taken.

**Claim B, that flat `_bmad-output/` state files force the full suite, is LIVE and fixed.** The pipeline writes flat state files directly under `_bmad-output/`, including `pipeline-continuation-log.md`, `arm-log.jsonl` and `operator-requests-history.md`. The map names no reader for them, so each one landed in the orphan set and ran everything. Range keying would not cure this either, because the consumer also commits these files.

**The fix as landed** (`e736263f`): the orphan-filter alternation is widened only, identically in both hooks (I66), at `.githooks/pre-push:757` and `core/git-hooks/pre-push:678`:

    ^(\.claude/\.ai-dlc-version|_bmad-output/ai-dlc-update/[^/]+|_bmad-output/[^/]+)$

It waives only the "unknown reader" verdict, and only for files directly under `_bmad-output/`. A flat file that the map names is in `.universe`, so it never reaches the filter and still selects its reader. Unmapped fixtures still run. A deeper path, and an `_bmad-output/` nested under another top, both remain orphans and still run all. The consumer's own remedy of an EXCLUDE top is fail-open here: excluding `_bmad-output` drops the whole top from the manifest, so a fixture reading a mapped `_bmad-output/` path stops being selected when that path changes. `core/fixtures/readset-skip/run.sh` moves `_bmad-output/other.md` from the near-miss battery to a positive arm, adds the near-misses `_bmad-output/sub/x.md` and `sub/_bmad-output/pipeline-continuation-log.md` (`:514`), adds flat positives for `pipeline-continuation-log.md`, the non-`.md` `arm-log.jsonl`, the dotfile `.pipeline-state` and a mapped `mapped-state.md`, and adds the mutants `dotstar`, `unanch`, `mdonly`, `nodot` and `onehook`. `mdonly` and `nodot` each die on behaviour, on the flat positive they stop waiving. `onehook` is the consumer hook left narrow, and I66 fails it.

**The waiver's cost, stated in both hooks' comment.** The waiver reads "the map names no reader" as "no reader". That is false on a map that is out of date, and a consumer's map does name readers of some flat files: graph's names 20 readers of `_bmad-output/.ai-dlc-context-nonce`. Those flat files are in `.universe` and select normally. A fixture that starts reading an unmapped flat file after the map was derived is skipped for a change to that path until the map is re-derived. That is the same exposure the `ai-dlc-update/` waiver already carries.

**Measured effect on the reference consumer: small.** Over graph's last 40 commits at `1f334be0`, read with `git diff-tree -r` on this hand, 7 non-merge commits touch a flat `_bmad-output/` file. Nine do so if the two merges are read against their first parent. An impossible-path control in the same script read 0. Re-derived read-only against graph's own map at `1f334be0` (`git show 1f334be0:.ai-dlc-fixture-readsets.tsv`, 19942 universe paths). For each of the 40 commits, the derivation took the `diff-tree -m --first-parent` path set, removed everything in the map's universe, and applied the shipped base filter and then the widened one. 39 commits carry an orphan under the base filter and 34 under the widened one, so the widening cures 5. A filter of an impossible path changed 0 of the 40. The 34 still run all on deeper or other paths. Counted per commit, their orphans fall under `_bmad-output/<dir>/` 22 times, `rebalancer/` 10, `docs/` 9, `scripts/` 5, `web/`, `tests/` and `.claude/` 3 each, the map file itself 2, and `.gitleaksignore` 1. The contract adversary had reported 36 with an orphan and 31 left over. The cured count of 5 agrees.

**The consumer must annotate its own receipt by hand.** The consumer's receipt is `grep -qF '/.now" 2>/dev/null | sed'` against `core/git-hooks/pre-push` at the pulled ref. It anchors on line 602's text, and only the rejected range fix would change that line. The release tip still carries that text at `:602`, so under the consumer ledger's polarity, where exit 0 means still reproducing, the entry stays live after the pull. It closes only when someone records the claim-A refusal by hand.

**Wrong fixes rejected, each scored 1 by the receipt below:**
- `.*` in place of `[^/]+`, which crosses `/`.
- The pattern without its anchors.
- Listing `_bmad-output` as an EXCLUDE top in `scripts/suite-content-key.sh`, which is the consumer's remedy and fail-open.
- Clearing every orphan when any changed path is a flat state file.
- A `.md`-only waiver, `_bmad-output/[^/]+\.md`.
- A waiver that excludes dotfiles, `_bmad-output/[^/.][^/]*`.

Range keying is the refused claim A. Dropping the paths from the manifest or from `readset_drop_excluded` is the same fail-open shape as the EXCLUDE top.

**Receipt.** Modelled on BL-432/433's. It extracts `FIXTURE_POOL_BEGIN..END` from `.githooks/pre-push` and seeds a git tree with a copy of `scripts/suite-content-key.sh`. The seed's map has `alpha` reading `src/a.sh` and `mstate` reading `_bmad-output/mapped-state.md`, and `gamma` is unmapped. The receipt records a manifest, makes one edit per arm, and drives `apply_readset_skip`. Nine arms:
- An edit to the zero-reader flat `_bmad-output/pipeline-continuation-log.md` selects only `gamma`.
- A new flat state file also selects only `gamma`.
- An edit to the non-`.md` flat `_bmad-output/arm-log.jsonl` selects only `gamma`.
- An edit to the flat dotfile `_bmad-output/.pipeline-state` selects only `gamma`.
- An edit to the mapped flat file selects `mstate` and `gamma`.
- `_bmad-output/sub/x.md` runs all.
- `sub/_bmad-output/pipeline-continuation-log.md` runs all.
- A flat file beside `.claude/settings.json` runs all.
- An uncommitted edit to `src/a.sh` selects `alpha` and `gamma`.

The receipt exits 9 if the seed does not form or the recorded manifest is empty. Scored under `bash -c 'set -uo pipefail; …'` from the repo root: release tip 0; base 1; the two sibling fixes alone 1; each of the six wrong fixes above 1; a cwd with no hook 9.

verify: sh unset AI_DLC_FIXTURE_NO_SKIP GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE; H=.githooks/pre-push; K=scripts/suite-content-key.sh; [ -f "$H" ] && [ -f "$K" ] || exit 9; command -v shasum >/dev/null || exit 9; w="$(mktemp -d)" || exit 9; sed -n '/^# FIXTURE_POOL_BEGIN/,/^# FIXTURE_POOL_END/p' "$H" > "$w/pool.sh"; grep -q '^readset_manifest()' "$w/pool.sh" && grep -q '^apply_readset_skip()' "$w/pool.sh" || exit 9; ALL='0:alpha,mstate,gamma,'; p() { t="$w/$1"; o="$w/$1.o"; mkdir -p "$o" "$t/src" "$t/scripts" "$t/.claude" "$t/sub/_bmad-output" "$t/_bmad-output/sub" || return 9; cp "$K" "$t/scripts/" || return 9; echo v > "$t/src/a.sh"; echo s > "$t/.claude/settings.json"; echo m > "$t/_bmad-output/mapped-state.md"; echo l > "$t/_bmad-output/pipeline-continuation-log.md"; echo j > "$t/_bmad-output/arm-log.jsonl"; echo d > "$t/_bmad-output/.pipeline-state"; echo x > "$t/_bmad-output/sub/x.md"; echo n > "$t/sub/_bmad-output/pipeline-continuation-log.md"; printf 'alpha\tsrc/a.sh\nmstate\t_bmad-output/mapped-state.md\n' > "$t/.ai-dlc-fixture-readsets.tsv"; ( cd "$t" && git init -q . && git add -A && git -c user.name=r -c user.email=r@r -c commit.gpgsign=false commit -qm s ) >/dev/null 2>&1 || return 9; ( cd "$t" || exit 9; . "$w/pool.sh" >/dev/null 2>&1; readset_manifest "$o"; [ -s "$o/.now" ] || exit 9; cp "$o/.now" .git/ai-dlc-fixture-verified || exit 9; eval "$2" || exit 9; printf 'x/%s/\n' alpha mstate gamma > "$o/list"; READSET_NO_CHANGE=0; apply_readset_skip "$o/list" "$o" >/dev/null 2>&1; printf '%s:%s' "$READSET_NO_CHANGE" "$(sed 's|^x/||; s|/$||' "$o/list" | tr '\n' ,)" ); }; f=0; chk() { r="$(p "$1" "$2")" || { echo "NO-RUN $1" >&2; exit 9; }; [ "$r" = "$3" ] || { echo "BL-443 $1: want $3 got $r" >&2; f=1; }; }; chk flat-zero 'echo l2 >> _bmad-output/pipeline-continuation-log.md' '0:gamma,'; chk flat-new 'echo s > _bmad-output/story-7-state.md' '0:gamma,'; chk flat-jsonl 'echo j >> _bmad-output/arm-log.jsonl' '0:gamma,'; chk flat-dotfile 'echo d >> _bmad-output/.pipeline-state' '0:gamma,'; chk flat-mapped 'echo m2 >> _bmad-output/mapped-state.md' '0:mstate,gamma,'; chk deeper 'echo x2 >> _bmad-output/sub/x.md' "$ALL"; chk nested 'echo n2 >> sub/_bmad-output/pipeline-continuation-log.md' "$ALL"; chk flat+settings 'echo l2 >> _bmad-output/pipeline-continuation-log.md; echo s2 > .claude/settings.json' "$ALL"; chk uncommitted 'echo v2 > src/a.sh' '0:alpha,gamma,'; exit $f

## BL-444 — an operator attribution and a repository-state claim could each be written with no cited source, and a later pass graded against them

**DEFECT.**

Filed by the consumer as PC-S316-OPERATOR-ATTRIBUTION-AND-STATE-CLAIMS-NEED-A-CITED-SOURCE.

**Two claims, scored separately.**
- (a) A requirement, AC or decision attributed to the operator carried no quote and no locator, so
  nothing distinguished a real operator statement from an invented one, and it entered the locked set
  and was graded against. The operator-citation check core does carry, `gate-validation.md` Check 2a
  (`validate-escalation-resolution.sh`), has escalation entries as its subject: its header
  (`core/scripts/validate-escalation-resolution.sh:2-3`) names an operator-gated HARD_BLOCK marked
  RESOLVED.
- (b) A gate evidence row asserting repository state (committed, tracked, gitignored, absent, red,
  green) did not have to carry the command that produced it. Check 12 already required an absence
  claim to carry a control; it did not require a state claim to carry its command.

**The fix, as landed.**
- (b) `core/skills/ai-dlc/steps/gate-validation.md:875`, inside Check 12 directly after the
  absence-control paragraph: `**A state claim MUST carry its command.**` The row carries the command
  and its output, or it is rewritten before proceeding.
- (a) `core/skills/ai-dlc/rule-bodies/rule-13.md:18`, inside Rule 13 proper and above `## HANDOFF
  PROTOCOL`: `**An operator attribution MUST cite the operator's message.**` A verbatim quote plus a
  locator. An attribution with no citable message never entered the locked set: it is struck at
  extraction, is not graded against and is not carried forward, and striking it is not a Rule 13
  divergence. That wording keeps it out of Rule 13's HARD_BLOCK-to-drop path. A project-memory
  entry's path is an acceptable locator for that source class, which resolves the source line at
  `discovery.md:177`.
- Pointer at `core/skills/ai-dlc/steps/discovery.md:179`, inside §4a: `**Every operator attribution
  carries a quote and a locator**`.
- Reviewer arm at `core/team-roles/adversary.md:201`, its own rung under `## Severity`: `### An
  uncited operator attribution is a MAJOR`. It checks that a quote AND a locator are PRESENT, because
  the adversary has no transcript to check the quote against. CRITICAL only where the artifact grades
  an AC or locks a requirement against the attribution. Its repair is to supply the citation; striking
  is allowed only where the author confirms no citable message exists, per `rule-13.md`, because an
  attribution with a message behind it is a locked requirement and dropping it needs the HARD_BLOCK.

**No mechanism.** Rule 31's own carrier note (`core/skills/ai-dlc/SKILL.md:932-940`) records the
measurement: a block-grain detector for an uncited claim flagged 6074 blocks across 890 of 998 story
files, and was passable by adding any unrelated citation. A detector for (a) or (b) has the same
shape and the same false-positive set, so neither is mechanised and the adversary rung is the carrier.

**The consumer's receipt cannot close against this fix.** Its `verify: theirs_lacks
core/skills/ai-dlc/steps/gate-validation.md "XAP"` closes only when core's `gate-validation.md`
carries the consumer's own `XAP` token, and core prose never will: `XAP` occurs 0 times in that file
at base and at the fix, against 8 for `Check 12` in the same file at the fix. The entry therefore
needs a hand annotation on the consumer side when this release is pulled. **Do NOT suggest retiring
the consumer's XAP.** Core's (a) and (b) carry no gate FAIL; they are prose plus an adversary MAJOR.
The consumer's XAP is universal and FAILS the gate, per the batch-195 contract adversary's reading of
it, so retiring it on the strength of this release would trade a blocking check for a non-blocking one.
The layer-drift rehearsal of this release against a scratch copy of the consumer, including XAP's
row, is reported separately by the measurement hand.

**Wrong fixes rejected.**
- Widening Check 2a / `validate-escalation-resolution.sh` to every artifact. That script's subject
  is the RESOLVED/OVERRIDDEN escalation entry and its operator citation; a story's or a gate log's
  operator attribution is not an escalation entry, so widening it changes the subject rather than
  extending the check.
- Folding (b) into Rule 31. Rule 31 binds countable assertions, has no carrier (declared a GAP), and
  is read nowhere near Check 12's evidence rows. A state claim placed there is out of the section the
  gate executes. The receipt scores this build 1.

**Receipt.** Paragraph-joined and section-bounded: each file is folded to one line per paragraph
with fenced and `<!-- -->` lines skipped, then each pin must open a paragraph INSIDE its span: Check
12 (`### 12.` to `### 13.`), Rule 13 (to `## HANDOFF`), discovery §4a (to `### 4b`), and adversary
`## Severity`. Scored under `bash -c 'set -uo pipefail; ...'` from the tree root:

| tree | exit |
|---|---|
| fix (release tip) | 0 |
| base `f8384eea` | 1 |
| base plus every pin text appended as trailing paragraphs to every file the receipt names | 1 |
| state-claim paragraph moved into SKILL.md Rule 31, Check 12 untouched | 1 |
| state-claim paragraph wrapped in a fenced block inside Check 12 | 1 |
| BL-445's fix alone on base | 1 |
| BL-446's fix alone on base | 1 |
| rewording: both bold leads kept, bodies rewritten and re-wrapped at 50-60 columns | 0 |

The pin holds the bold leads verbatim and accepts any rewording of the body that keeps the words
`output` (Check 12) and `locator` (Rule 13).

verify: sh g=core/skills/ai-dlc/steps/gate-validation.md; r=core/skills/ai-dlc/rule-bodies/rule-13.md; d=core/skills/ai-dlc/steps/discovery.md; a=core/team-roles/adversary.md; for f in "$g" "$r" "$d" "$a"; do [ -f "$f" ] || exit 9; done; PJ='function f(){ if(p!=""){gsub(/[[:space:]]+/," ",p); sub(/^ /,"",p); print p}; p="" } /^[[:space:]]*```/{f(); z=!z; next} z{next} /^[[:space:]]*<!--/{f(); if($0!~/-->/)m=1; next} m{if($0~/-->/)m=0; next} /^[[:space:]]*$/{f(); next} /^#/{f(); print; next} {p=p" "$0} END{f()}'; sp(){ awk "$PJ" "$1" | awk -v S="$2" -v E="$3" 'index($0,E)==1&&s{s=0} index($0,S)==1{s=1;next} s'; }; c1(){ awk -v L="$1" -v X="$2" '(L==""||index($0,L)==1)&&(X==""||index($0,X)){c++} END{print c+0}'; }; [ "$(sp "$g" '### 12.' '### 13.' | c1 '**A state claim MUST carry its command.**' 'output')" = 1 ] || exit 1; [ "$(sp "$r" '### Rule 13 --' '## HANDOFF' | c1 '**An operator attribution MUST cite the operator' 'locator')" = 1 ] || exit 1; [ "$(sp "$d" '### 4a.' '### 4b' | c1 '**Every operator attribution carries a quote and a locator**' '')" = 1 ] || exit 1; [ "$(sp "$a" '## Severity' '## ' | awk '$0=="### An uncited operator attribution is a MAJOR"{c++} END{print c+0}')" = 1 ] || exit 1; exit 0

## BL-445 — the bug-analysis root-cause claim reached the fix story with no adversarial pass on its soundness

**DEFECT.**

Filed by the consumer as PC-S316-NO-ADVERSARIAL-PASS-ON-THE-BUG-ANALYSIS-ROOT-CAUSE-CLAIM.

**Claims, scored separately.**
- `bug-investigation.md` ran no adversarial review between the root-cause analysis (§2) and the fix
  story (§3). The only review was §4's story validation cycle, which reviews the STORY, so a
  root cause placed where the defect is observed rather than where the wrong value is produced passed
  every pass downstream.
- Any review added there must not hold operator-applicable relief behind it (§2b).
- The folded-defect routes named the range they run as `0–2b`, so a new §2c would be skipped on
  both of them.

**The fix, as landed.**
- `core/skills/ai-dlc/steps/bug-investigation.md:102`, a new `### 2c. Adversarial verification of
  the root-cause claim` between §2b and `### 3.`, titled to match the consumer's own extension so
  layer-drift can see the overlap. It dispatches ONE `adversary` (Rule 19) to run
  `/bmad-review-adversarial-general` on `bug-analysis.md`, one-shot and `mode: subagent`, against the
  soundness of the root cause: does each falsification-ladder rung rule its layer out, is a layer
  missing, does the evidence fit another cause equally well, is the defect placed where it is
  observed rather than produced. Findings go to
  `_bmad-output/planning-artifacts/bug-analysis-adversarial.md` with a
  `SKILL_INVOCATION_PROVENANCE v1` block whose `artifact:` names `bug-analysis.md` and which carries
  no `verdict`. `:122` requires every CRITICAL and MAJOR disposed of before §3, by amending the
  analysis or recording counter-evidence in the fix story. `:126` copies §4's relief sentence, so a
  one-shot finding that yields operator relief goes to the operator when it is found.
- `:100`, §2b's last sentence: relief is not held behind any review between sections 2 and 3, "§2c
  included".
- `core/skills/ai-dlc/steps/route.md:421` and `core/skills/ai-dlc/steps/stories-test-strategy.md:505-507`
  now read `0–2c`, and the stories-test-strategy `0–4` path names §2c explicitly. `grep -rnE
  '0(–|-)2b' core/ --exclude-dir=fixtures` reads 0, against 2 for `0(–|-)2c` in the same tree.
  Without the exclusion the counts include `process-rule-pins`' own probe text.
- The new sibling is bug-keyed, not sprint-keyed, so it joins `bug-analysis.md`'s Rule 24 exemption
  everywhere that exemption is written: `core/scripts/validate-draft-stamps.sh:53-67`, whose
  derivation now returns 14 basenames with the command beside the count, and `:112-121`,
  `core/skills/ai-dlc/rule-bodies/rule-24.md:70`,
  `core/skills/ai-dlc/steps/gate-validation.md:2009-2010`, and
  `core/fixtures/check-23-draft-stamps/README.md:51,74`. The check-23 decoy the contract first asked
  for was DROPPED: `DRAFTS` is an exact-basename whitelist, so a decoy named
  `bug-analysis-adversarial.md` cannot fail with or without the exemption.

**NOTE: the Check 17 mechanism arm is NOT built.** The arm would fail a gate when a fix story states
a root cause and `bug-analysis-adversarial.md` is absent. It needs a PENDING arm for fix stories
written before this release and a false-positive set measured on a scratch copy of the consumer's
live slot. Neither exists, so this release ships prose and a text-pin fixture only.

**Wrong fixes rejected.**
- Adding the soundness questions to §4's fix-story validation cycle. §4 reviews the story after the
  root cause is written into it, which is the gap. The receipt scores the §2c body moved into §4 as 1.
- Stamping the sibling under `planning-artifacts/s<N>/`. A bug has no sprint key, and two bugs in one
  sprint would collide on one stamped path; that is the reason `bug-analysis.md` is exempt.
- §2c placed after `### 3.`. The fix story would already carry the claim. The receipt scores it 1.

**Receipt.** Paragraph-joined and section-bounded, fenced and `<!-- -->` lines skipped. It requires
the `### 2c.` heading verbatim, immediately after a `### 2b.` heading and immediately before a
`### 3.` heading; inside §2c, the bold lead, the full findings path and the disposition lead; `§2c
included` inside §2b; and in `route.md` and `stories-test-strategy.md`, no `0–2b` (either dash) and at
least one `sections 0–2c`. Scored under `bash -c 'set -uo pipefail; ...'` from the tree root:

| tree | exit |
|---|---|
| fix (release tip) | 0 |
| base `f8384eea` | 1 |
| base plus every pin text appended as trailing paragraphs to every file the receipt names | 1 |
| §2c moved to after `### 3.` | 1 |
| §2c's body folded into §4, heading removed | 1 |
| BL-444's fix alone on base | 1 |
| BL-446's fix alone on base | 1 |
| rewording: three §2c paragraphs re-wrapped at 45-55 columns | 0 |

The alternate build is a re-wrap, not a rewording. The pin intentionally refuses rewording of four
things: the `### 2c.` title, which layer-drift keys on; the two bold leads; and the full findings
path. Everything else in §2c may be reworded.

verify: sh b=core/skills/ai-dlc/steps/bug-investigation.md; ro=core/skills/ai-dlc/steps/route.md; st=core/skills/ai-dlc/steps/stories-test-strategy.md; for f in "$b" "$ro" "$st"; do [ -f "$f" ] || exit 9; done; PJ='function f(){ if(p!=""){gsub(/[[:space:]]+/," ",p); sub(/^ /,"",p); print p}; p="" } /^[[:space:]]*```/{f(); z=!z; next} z{next} /^[[:space:]]*<!--/{f(); if($0!~/-->/)m=1; next} m{if($0~/-->/)m=0; next} /^[[:space:]]*$/{f(); next} /^#/{f(); print; next} {p=p" "$0} END{f()}'; sp(){ awk "$PJ" "$1" | awk -v S="$2" -v E="$3" 'index($0,E)==1&&s{s=0} index($0,S)==1{s=1;next} s'; }; c1(){ awk -v L="$1" -v X="$2" '(L==""||index($0,L)==1)&&(X==""||index($0,X)){c++} END{print c+0}'; }; [ "$(awk "$PJ" "$b" | awk '/^### /{if(q&&index($0,"### 3.")==1)ok++; q=(pb&&$0=="### 2c. Adversarial verification of the root-cause claim"); pb=(index($0,"### 2b.")==1)} END{print ok+0}')" = 1 ] || exit 1; [ "$(sp "$b" '### 2c.' '### ' | c1 '**The root-cause claim gets an adversarial pass before section 3.**' 'adversary')" = 1 ] || exit 1; [ "$(sp "$b" '### 2c.' '### ' | c1 '' '_bmad-output/planning-artifacts/bug-analysis-adversarial.md')" -ge 1 ] || exit 1; [ "$(sp "$b" '### 2c.' '### ' | c1 '**Dispose of every CRITICAL and MAJOR before section 3**' '')" = 1 ] || exit 1; [ "$(sp "$b" '### 2b.' '### ' | c1 '' '§2c included')" = 1 ] || exit 1; for f in "$ro" "$st"; do grep -qE '0(–|-)2b' "$f" && exit 1; [ "$(awk "$PJ" "$f" | awk 'index($0,"sections 0–2c")||index($0,"sections 0-2c"){c++} END{print c+0}')" -ge 1 ] || exit 1; done; exit 0

## BL-446 — a later event that invalidates an authorization's premise was absorbed in gate-log prose instead of going back to the operator

**DEFECT.**

Filed by the consumer as PC-S316-LATER-EVENT-INVALIDATING-AN-AUTHORIZATION-PREMISE-MUST-RETURN-TO-THE-OPERATOR.

**Claims, scored separately.**
- When an outcome a RESOLVED/OVERRIDDEN authorization relied on later failed to occur, nothing
  required the change to go back to the operator; it could be absorbed in gate-log prose and the
  authorization kept on.
- No reviewer was told to look for it.

**The fix, as landed.**
- `core/skills/ai-dlc/escalations.md:200`, directly after the permanent-default disclosure and
  before terminal-entry archival: `**Authorization-premise invalidation disclosure.**` File a new
  `HARD_BLOCK` entry citing the earlier authorization (id and timestamp) and the invalidating event,
  and put the question back to the operator before the affected work reaches deploy-validate or the
  Production Validation Checkpoint. The status is `HARD_BLOCK` because the status vocabulary is closed.
- Reviewer arm at `core/team-roles/adversary.md:219`, its own rung under `## Severity` beside
  BL-444's: `### A premise a later event contradicted is a MAJOR`.
- Pointer in `core/skills/ai-dlc/SKILL.md:383-385`, Rule 12, beside the AC verification-category
  cross-reference.

**No mechanism.** Whether an outcome was the PREMISE of an authorization is a judgment about intent.
No act separates a premise from an incidental mention, so there is nothing for a gate to deny; the
adversary rung is the carrier. `escalations.md:207-208` says the same in the shipped text.

**Wrong fixes rejected.**
- Auto-expiring a RESOLVED entry after N gates. That expires authorizations whose premises still
  hold and leaves one invalidated in the first gate alive until N.
- Folding this into the AC verification-category disclosure. That disclosure fires when a resolution
  changes how an AC is verified; a premise invalidation happens later and to an authorization that
  may touch no AC. The receipt scores the paragraph folded into it, lead removed, as 1.

**Receipt.** Paragraph-joined and section-bounded, fenced and `<!-- -->` lines skipped. The bold lead
must open a paragraph between `**Permanent-default change disclosure.**` and `**Terminal-entry
archival`, and that paragraph must carry `HARD_BLOCK` and `operator`. The adversary rung must sit
under `## Severity`, and Rule 12 in SKILL.md must name the disclosure. Scored under `bash -c 'set -uo
pipefail; ...'` from the tree root:

| tree | exit |
|---|---|
| fix (release tip) | 0 |
| base `f8384eea` | 1 |
| base plus every pin text appended as trailing paragraphs to every file the receipt names | 1 |
| paragraph moved to after `**Terminal-entry archival` | 1 |
| paragraph folded into the AC verification-category disclosure, lead removed | 1 |
| BL-444's fix alone on base | 1 |
| BL-445's fix alone on base | 1 |
| rewording: bold lead kept, body rewritten and re-wrapped at 52 columns | 0 |

verify: sh e=core/skills/ai-dlc/escalations.md; a=core/team-roles/adversary.md; k=core/skills/ai-dlc/SKILL.md; for f in "$e" "$a" "$k"; do [ -f "$f" ] || exit 9; done; PJ='function f(){ if(p!=""){gsub(/[[:space:]]+/," ",p); sub(/^ /,"",p); print p}; p="" } /^[[:space:]]*```/{f(); z=!z; next} z{next} /^[[:space:]]*<!--/{f(); if($0!~/-->/)m=1; next} m{if($0~/-->/)m=0; next} /^[[:space:]]*$/{f(); next} /^#/{f(); print; next} {p=p" "$0} END{f()}'; sp(){ awk "$PJ" "$1" | awk -v S="$2" -v E="$3" 'index($0,E)==1&&s{s=0} index($0,S)==1{s=1;next} s'; }; c1(){ awk -v L="$1" -v X="$2" -v Y="$3" '(L==""||index($0,L)==1)&&(X==""||index($0,X))&&(Y==""||index($0,Y)){c++} END{print c+0}'; }; [ "$(sp "$e" '**Permanent-default change disclosure.**' '**Terminal-entry archival' | c1 '**Authorization-premise invalidation disclosure.**' 'HARD_BLOCK' 'operator')" = 1 ] || exit 1; [ "$(sp "$a" '## Severity' '## ' | awk '$0=="### A premise a later event contradicted is a MAJOR"{c++} END{print c+0}')" = 1 ] || exit 1; [ "$(sp "$k" '### Rule 12 ' '### ' | c1 '' 'Authorization-premise invalidation disclosure' '')" -ge 1 ] || exit 1; exit 0

## BL-447 — `apply.sh` handed back a setup-sited file as a manual semantic merge when its only consumer delta was its setup values

**DEFECT.** Filed by the consumer as `PC-S316-APPLY-HANDS-BACK-A-SEMANTIC-MERGE-FOR-A-FILE-WHOSE-ONLY-DELTA-IS-SETUP-SITES`. A file `reconcile/setup-sites.md` declares carries values `ai-dlc-setup` filled in, so it never byte-matches base, and every upstream change to it buckets `BOTH-CHANGED->CLASSIFY`. At base, `apply.sh` handed each such file back as `WORKLIST semantic-merge`, a manual three-way merge whose whole content was "take theirs, keep the values". **This is a bootstrapping engine, and the fix cannot protect the pull that delivers it, though only in one case.** A deferred pull (`--carried-machinery-slice`) runs the consumer's old engine over the range and gets today's rows. A non-deferred pull lands the new `apply.sh` at step 2 and re-invokes it, so that pull is classified by the fixed engine.

**Five claims, each scored.** Line numbers are on the batch's base, where the release's two siblings touched none of these files.
- **C1, that the `*CLASSIFY*` arm never asks whether the path is setup-sited, is LIVE and fixed.** `preclassify.sh:827` buckets the file `BOTH-CHANGED->CLASSIFY`, and the arm at `apply.sh:1044-1067` emits `semantic-merge` with no sited-path test.
- **C2, that `unregistered-drift.sh` emits `CORE-TEMPLATE-SUBSTITUTED` for these files, is LIVE.** It is not the defect. It is why that row cannot be the eligibility key (W3 below).
- **C3, that `apply.sh` performs a mask/reinject transform the fix should extend, is PARTLY FALSE.** The transform exists only as agent prose (`SKILL.md:2370-2403`), and `setup-site-drift.sh:32-35` says in as many words that `apply.sh` has none. The fix is a new mechanism in `apply.sh`, not an extension of an existing one.
- **C4, that `--finish` cannot verify a hand merge of a sited file, is LIVE and fixed.** `apply.sh:706` excludes sited paths from the in-flight marker, and `:2305` emits `NOTE finish-unverified` for every one of them unconditionally.
- **C5, that substituting the value for the token text would do, is FALSE as a remedy.** Theirs carries the same token text in doc comments (`deploy-validate.md:45`, `:165`; `qa.md:14` at theirs), so a substitution rewrites those comments too (W2 below).

**The fix as landed** (line numbers are on the release tip):
- `setup_site_merge` at `apply.sh:616-694` resolves the file only when four predicates, each asked of a program, all hold. **(a)** At `:653-655`, against BASE this one file differs only inside its declared spans. That is a per-file answer from `setup-site-drift.sh --file`; the tree-level exit read 1 on the reproduction while both files were OK. **(d)** At `:658-682`, no line theirs ADDED carries a `{word}` outside an HTML comment, where a `{word}` preceded by `$` is a shell expansion and does not count. Comment state is tracked across lines. **(b)** At `:683-684`, `git merge-file` exits 0. **(c)** At `:685-687`, the merged result, not yet written, equals theirs outside its spans, checked with `--file --ours` on the temp file. Every ssd call needs exit 0 AND an `SETUP-SITE-OK` row (`ssm_ok`, `:615`), so a run that compared nothing is not a pass.
- **Two already-merged acceptances run before (a)-(d).** If either holds, the function returns 0 with no content write and applies only theirs' exec bit.
  - The first, at `:628-637`, needs `git merge-file -p ours base theirs` to exit 0 with output byte-equal to ours, AND `setup-site-drift.sh --file` against THEIRS to read OK. The merge-file conjunct is the round-2 repair below.
  - The second, at `:638-652`, needs ssd `--file` against THEIRS to read OK, AND the text of every declared span to be identical at BASE and at THEIRS. Span text comes from `setup-site-drift.sh --span-text`, each side must be non-empty, and the two strings must be equal. This is the round-3 repair.
- **Mode and write** at `:688-692`: a `cp -p` seed of `$cons.incoming.$$`, the merged bytes, `sync_mode_from_theirs`, then `mv`, as `overwrite_from_theirs` writes.
- **The gate** at `:1185-1197` tries the merge only when `retired-tokens.sh` exited 0 (`rt_rc`) and named nothing to re-point (`rt` empty). On success the row is `RESOLVED<TAB>setup-site-merge<TAB><rel>`. Every other outcome falls through to the hand-back rows below it, which the release keeps byte-identical to base.
- **The exact-bucket test was deleted as vacuous** (round 3), which amends contract D8. Every `*CLASSIFY*` bucket that can name a sited path already falls back inside `setup_site_merge`. BOTH-ADDED has no base blob, UPSTREAM-DELETED+consumer-modified has no theirs blob, and UPSTREAM-MOD+consumer-deleted has no consumer file; the ORPHANED-* rows name no matching consumer path. So the test changed no outcome. The fixture records this at `run.sh:379-383`, and arms D8b and D8 hold the fallbacks. **How the verdict was settled:** the tip was compared end to end against a copy with the bucket test restored.
  - **The first comparison could not discriminate.** Its line in `r3final-e2e.sh` printed ROWS DIFFER in every world, because its normaliser used `\b`, which BSD `sed -E` does not implement. Commit shas in the `RESOLVED consistent` and `RESOLVED restamp` rows therefore leaked through.
  - **With explicit non-hex boundaries** (the session's `t4/norm.sh`), all 9 worlds read IDENTICAL for the tip against the restored-bucket copy. A control pair, clean against spanD, still differs.
  - **A second harness agrees:** `tip3b-e2e.sh` reads identical on clean, d8add, upDel and d8del.
- **`setup-site-drift.sh --file <core-path> [--ours <path> | --span-text]`** at `:5` and `:70-93`.
  - `--file` answers for one declared file and refuses an undeclared one.
  - `--ours` compares a named copy of that file and requires `--file`.
  - `--span-text` (`:272-300`) prints one `SETUP-SITE-SPANTEXT` row carrying the span count and a checksum of the span lines at that ref. It prints no row when a site does not locate there, so an absent span is never equal to anything. It requires `--file` and takes no `--ours`.
- **ssd's `c`-hunk arm, the round-4 repair** (`setup-site-drift.sh:327-340`): a `c` hunk with unequal left and right lengths now emits `SETUP-SITE-DRIFT` on every single-line-site line it covers. Block sites are exempt. This is fail-closed only: a tree that read OK solely because an extra or missing line sat next to a filled value now reads DRIFT.
- **ssd's `a|d` arm, the round-5 repair** (`setup-site-drift.sh:351-363`): a `d` hunk now needs every deleted line, from its first to its last, to sit inside a heading block. An `a` hunk still tests only its insertion point. This is fail-closed only as well.
- **D4, a lost `next_heading`,** at `setup-site-drift.sh:250-254` now emits `SETUP-SITE-ANCHOR-LOST` and exits 1. Before, it widened the span to EOF and could read OK. The arm is `core/fixtures/setup-site-drift/run.sh:198-216`, and the `eof-widening` mutant is at `:313-324`.
- **`--finish`** at `apply.sh:2443-2457` runs `setup-site-drift.sh --file` against THEIRS for each sited CLASSIFY path. On OK it emits no row. Otherwise it keeps `NOTE finish-unverified` and carries ssd's own rows. It is never a WORKLIST. Resolved paths stay out of the marker's classify hashes (`:737-739`), because a check this mode adds must not start withholding on them.
- `SKILL.md:1659` and `:2385` and `layer-contract.yaml:406` name `setup-site-merge`.
- `core/fixtures/apply-setup-sited-merge/` is a new SHIPPING fixture, registered in `scripts/uninstall.sh` and both manifests. It has 60 arms: 36 behavioural and 24 mutant kills. It prints `SKIP: subject predates setup-site-merge` against an engine without the emission line, and it locates `reconcile/` beside itself with `pick()` rather than walking up for a root. The arms added after the first tip are:
  - SpD and SpQ (round 2).
  - SpF and D1f (round 3). In SpF, theirs adds a line inside qa.md's Ownership block away from the value, and the file resolves carrying it. In D1f, run 1 merges a fenced block added beside an existing fence, and run 2 resolves with no write and the block present once.
  - DlI, DlD and DlB (round 4): theirs deletes a line adjacent to a filled single-line site, and each file falls back.
  - CAd: a consumer line added right after the filled deploy site is outside every span, and the file falls back.
  - BLK: a block span that changes length on both sides still resolves, which shows that the length test does not reach block sites.
  - QD and QDc (round 5): a consumer deletion that runs from inside qa.md's Ownership block through `## Responsibilities` falls back untouched, and the same comment reword without the deletion still resolves.
  - D+dol, D+ml and D+com, the pass direction for (d): a `${LOGDIR}` shell expansion, a multi-line comment carrying a token, and a comment-only reword each resolve.
  - M2: after `chmod -x` on the merged file, a re-run restores theirs' exec bit.
  - FIN, the `--finish` branch.
  - INC: no driven world holds a `*.incoming.*` temp.

  `untouched()` compares mtime as well as bytes, inode and mode, which is what sees a write-then-restore.

**The fix needed four corrections after the first release tip.**

**Round-2 BLOCKER.** At the first release tip, the already-merged shortcut asked only whether ours equalled theirs outside the spans, and it ran BEFORE (a)-(d). A theirs edit INSIDE a span, made where the locator still matched, therefore passed the shortcut on the FIRST run. The file was reported `RESOLVED setup-site-merge` and theirs' edit was dropped without a write. Two worlds were measured. In spanD, theirs changes the value line to `{deploy_command} --wait`. In spanQ, theirs rewords the doc comment inside qa.md's `## Ownership` block. The repair adds the conjunct that `git merge-file -p ours base theirs` must exit 0 with output byte-equal to ours. SpD and SpQ pin it, and so does the `bareShort` mutant, which is the shortcut as it first shipped (`if true`).

**Round-3 DEFECT.** The repaired shortcut handed back a file it had merged itself, whenever theirs added a fenced block next to an existing fence. On run 2, `git merge-file` placed the block ambiguously, exited 0 and duplicated it, so the `cmp` against ours failed on a file that was already exactly right. The repair is the second acceptance above. D1f pins it, SpF pins its span-identity conjunct, and so do the `spanId` and `rcOnly` mutants.

**Round-4 BLOCKER.** The root cause was ssd's `c`-hunk arm, which checked only a hunk's LEFT-side lines. `diff` folds a line deleted beside a single-line site into the site's own hunk (`6c6,7`), and that hunk's only left line is the allowed site line. So when theirs deleted the line adjacent to a filled site, ssd read the consumer copy, which still carried the line, as OK against THEIRS. The second acceptance then resolved the file on the FIRST run with nothing written, the stamp advanced past theirs' deletion, and the loss was permanent. The measured worlds are delIM, delDV and delDVb. The repair is the length test above. The same change closes the matching blind spot in check (a), where a consumer adds a line right after a filled site. DlI, DlD, DlB and CAd pin it, and so do the `laxC` and `laxCa` mutants. BLK holds the block-site exemption. **Round 4 closed the `c` arm, and round 5 closes the same cause in the `a|d` arm's range test.** That arm tested only the hunk's first line (`in_span "$l1"`). So a consumer deletion that started inside a heading block and ran past its `next_heading` (the qd world) read OK in check (a), and apply emitted `RESOLVED setup-site-merge`. `DECISION drift` still withheld the restamp, but the row was wrong. The repair requires every left line of a `d` hunk to be in span.

**Wrong fixes rejected, each killed on behaviour by a named arm of the fixture:**
- **W1**, re-bucketing a sited BOTH-CHANGED file as an apply bucket. `overwrite_from_theirs` lands theirs' `{token}` lines over the consumer's values. Killed by C2 (mutant `W1`).
- **W2**, substituting token text with the value. It rewrites theirs' `<!-- {deploy_command}: … -->` comment. Killed by C2 (mutant `W2`).
- **W3**, keying eligibility on `CORE-TEMPLATE-SUBSTITUTED`. `unregistered-drift.sh:634-635` exempts a whole hunk whose base side carries any token, so a consumer edit to the doc comment beside a site passes it. Killed by B2t, where consumer and theirs made the same doc-comment edit (mutant `W3`).
- **W4**, skipping (c). A theirs rewording of the `after_line` anchor passes (a) and (b), and only (c) sees the lost anchor. Killed by B1 and B1b (mutant `W4`). **A theirs edit to a span line was NOT caught by (b) at the first tip**, because the shortcut ran before (b) and resolved it. That is the round-2 BLOCKER above. Since the round-2 repair the shortcut's merge-file conjunct refuses such an edit. (b) then catches it when the consumer filled the same line (arm MF, a merge-file conflict). Where the locator still matches and the merge is clean, it falls back through the shortcut-and-(c) path (arms SpD and SpQ).
- **The contract adversary's additions:** no (d), killed by D2, where theirs adds `{deploy_command} --retry` outside the site (mutant `noD`). No already-merged shortcut, killed by D1, where the second run falls back on its own write (`noIdem`). A tree-level (a), killed by D6a, where another file's drift hands back the clean target (`treeA`). No mode sync, killed by C3 (`mode`). Reading a non-zero ssd exit as a pass, killed by B1b (`ssdExit`). No retired-token gate, killed by D7 (`noD7`). D8 also holds a consumer-deleted sited path absent.
- **Added with rounds 3 and 4:** a shortcut that trusts merge-file's exit without comparing its output, killed by SpF (`rcOnly`). The second acceptance without span identity, killed by SpF (`spanId`) and by SpQ (`spanIdQ`). ssd's `c`-hunk test reading left lines only, killed by DlI (`laxC`) and, through (a), by CAd (`laxCa`). ssd's `d`-hunk test reading the first line only, killed by QD (`laxD`). The `*CLASSIFY*` bucket mutant was removed together with the bucket test it mutated.
- **Added with the round-2 repair:** the bare shortcut, killed by SpD (`bareShort`). (d) without the `$` exclusion, killed by D+dol (`dDol`). (d) resetting comment state per line, killed by D+ml (`dML`). (d) reading comment text as live, killed by D+com (`dCom`). A shortcut without the mode sync, killed by M2 (`idemMode`). A write path that leaks its temp, killed by INC (`leak`). Write-then-restore, killed by B1 through the mtime conjunct (`writeRestore`). `--finish` always dropping the NOTE, killed by FIN (`finNote`).

**Measured on the reference consumer.** On a scratch `file://` clone of graph at `b58e49d0`, with the consumer's report overlay from `1f334be0`, `apply.sh --carried-machinery-slice` ran over `d4354b7c..f8384eea`, once with the base engine and once with the release engine. The base engine emitted `WORKLIST semantic-merge` for `skills/ai-dlc/steps/deploy-validate.md` and `team-roles/qa.md` and left both files at their pre-pull bytes.
- **The release engine** emitted `RESOLVED setup-site-merge` for both files, and both are byte-equal to the consumer's hand merge in `1f334be0`.
- **The other rows:** both runs emit 20 rows, and the other 18 of 20 rows are identical to the base engine's run. A `diff` of the sorted (kind, class, path) rows shows exactly two changes: `WORKLIST semantic-merge` becomes `RESOLVED setup-site-merge` for each of the two files. The only full-detail difference is the `restamp-withheld` count, which went from 3 undisposed rows to 1.
- **Re-run:** a second ordinary run resolves both files with no write.
- **Breadth across graph's earlier pulls:**
  - On the 0.722.0 pull, `team-roles/dev.md` and `team-roles/qa.md` resolve, each equal to graph's committed reconcile result.
  - On the 0.691.0 pull, `deploy-validate.md` resolves, equal.
  - These are the same five resolutions the first release tip produced, so neither the round-4 nor the round-5 tightening flipped any of them to a hand-back.
- **The round-4 worlds:** delIM, delDV and delDVb now emit `WORKLIST semantic-merge`. ssd names the site line in each: `implementation.md:6`, `deploy-validate.md:19` and `deploy-validate.md:18`. Each file is left unwritten, with no `.incoming` temp behind it. In the world where the consumer adds a line right after a filled site, check (a) now reads DRIFT.

**Owed: a read-set trace for `apply-setup-sited-merge`.** The fixture is new and has no map entry, so the pre-push runner runs it on every push until someone traces it with `--tracer sandbox` and commits the map.

**Receipt.** It extracts the fixture, `core/fixtures/lib` (the fixture sources its preamble) and `reconcile/` from `${THEIRS:-HEAD}` to a tar FILE, checking git's exit. It refuses with 9 if the fixture is absent at that ref, if the archive is empty, or if the extraction directory sits inside a repository. It then runs the fixture under a fresh `mktemp -d`. It needs `apply-setup-sited-merge: PASS` with rc 0, and a `SKIP` line reads 1, because a SKIP means the engine at that ref predates the fix. `backlog-reverify.sh` sets no `THEIRS`, so the receipt reads HEAD. This differs from BL-441's working-tree receipts because `git archive` needs a ref, so an uncommitted engine edit is invisible to it. Base reads 9 where the siblings read 1, because the fixture does not exist there and the receipt cannot measure the subject. Scored under `bash -c 'set -uo pipefail; …'` from the repo root on the final tip:
- release tip 0;
- base `ab1586db` 9, and an unresolvable ref 9;
- base's `apply.sh` with the new fixture 1 (SKIP);
- W4 1, killed by B1 and B1b;
- `bareShort` 1, by SpD, SpQ, SpF and BLK;
- `rcOnly` 1, by SpF and BLK;
- `spanId` 1, by SpD, SpQ, SpF and BLK;
- `laxC` (in `setup-site-drift.sh`) 1, by DlI, DlD, DlB and CAd;
- `laxD` (in `setup-site-drift.sh`) 1, by QD.

Earlier tips also scored no-(d) 1 (by D2), `--finish` always dropping the NOTE 1 (by FIN), W3 1 (by B2t), tree-level (a) 1 (by D6a and D6b) and the since-removed `*CLASSIFY*` bucket 1 (by D8b). Each wrong build replaces `apply.sh` with the fixture's own mutant of it, so the fixture's mutant anchors for that build also report `DID NOT APPLY`. That makes each exit overdetermined, and those anchor failures come from the harness, not from behaviour. The behavioural kill named beside each build is the discriminating evidence.

verify: sh unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE; R="${THEIRS:-HEAD}"; F=core/fixtures/apply-setup-sited-merge; E=core/skills/ai-dlc-update/reconcile; git cat-file -e "${R}:${F}/run.sh" 2>/dev/null || exit 9; w="$(mktemp -d)" || exit 9; git archive --format=tar -o "$w/t.tar" "$R" "$F" core/fixtures/lib "$E" || exit 9; [ -s "$w/t.tar" ] || exit 9; mkdir "$w/x" && tar -xf "$w/t.tar" -C "$w/x" || exit 9; [ -f "$w/x/$F/run.sh" ] && [ -f "$w/x/core/fixtures/lib/preamble.sh" ] && [ -f "$w/x/$E/apply.sh" ] || exit 9; git -C "$w/x" rev-parse --git-dir >/dev/null 2>&1 && exit 9; ( cd "$w/x" && bash "$F/run.sh" ) > "$w/out" 2>&1 </dev/null; rc=$?; if grep -q '^SKIP' "$w/out"; then echo "BL-447: the fixture SKIPped -- the engine at $R predates setup-site-merge" >&2; exit 1; fi; if [ "$rc" -eq 0 ] && grep -qx 'apply-setup-sited-merge: PASS' "$w/out"; then exit 0; fi; echo "BL-447: fixture rc=$rc: $(grep -E 'FAIL|BROKEN' "$w/out" | head -3 | tr '\n' '|')" >&2; exit 1
