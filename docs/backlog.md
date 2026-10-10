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
IN THE SAME SESSIONS.** Here, `scripts/backlog-reverify.sh:334-335` reads **exit 0 as "the fix
is present"** and non-zero as "still reproduces". In a consumer's push-candidate ledger,
`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:2929` reads it the other way — **exit 0
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

## BL-474 — measure the first cross shard's serial tail before ruling on it

**DEFECT, open by operator ruling, batch 204.** `0.744.0` shards code review and QA execution across their part agents,
but the first cross shard still runs the one canonical suite run and every replay a part HANDED OVER, all in the frozen
worktree (Rule 28, "Code review and QA shard their execution too"; `BL-464`'s Track B paragraph). A hand-over is an AC
whose replay cannot reach GREEN in a fresh detached worktree at the frozen sha, so a per-group fresh copy repeats the
failure. The operator ruled, choosing among build-it-now, accept-it-serial and measure-first: **measure first, then
decide.** Until then the residue is recorded as not serial by design, never as a ruling that it may stay serial.

Measure on the reference consumer's first sharded code review or QA after it pulls `0.744.0`, from the shard directory
`merge-review-shards.sh` joins, read-only:
- the part count K and the cross group count G;
- the hand-over count N, from the part shards' `handovers: <n>` lines, and the `handover-run:` lines in the first cross
  shard, which must equal N;
- the first cross shard's wall clock from its dispatch to its file's final write, split into the canonical suite run and
  the hand-over replays, against the slowest part shard's.

Then put the measured tail to the operator with three choices, each with a marked recommendation drawn from the numbers.
**Shard it:** each cross group replays its share in an APFS clone (`cp -c`) of the frozen worktree with its setup state,
never a fresh checkout. It is unproven against absolute paths, local services, ports and databases inside the
environment, and is built as its own release with its own adversary. **Rule it serial by design:** Rule 28 and `BL-464`
record the operator's ruling. **Keep it open:** take a second sprint's measurement.

verify: manual -- close when the measurement above is recorded in this entry from a real consumer review and the operator has ruled on it.


## BL-481 — two fixtures cannot be traced even on an idle box, and ten run on every push

**DEFECT, filed at batch 204's close.** The `0.745.0` map trace, run in a full clone with nothing else on the machine
(load 3-5), OMITTED `readset-skip-digest-mutants` (the sandbox log stream dropped reports 1491 times) and
`self-update-gate` (958). Those are properties of the fixtures under the tracer, not of load. The gate that shipped
`0.745.0` printed 10 of 248 fixture directories UNMAPPED and therefore always run:
`adversarial-shard-merge-mutants check-24-adversarial-convergence implementation-join-yield procsub-staged-refusal-boot
readset-skip-digest-mutants remediator-shard-join-mutants review-shard-merge-mutants self-update-fixture-log-mutants
self-update-gate subject-partition`. Derive the current set from any push's `read-set map: ... UNMAPPED` line rather
than from this list.

The hermetic-fixtures program (`docs/plans/hermetic-fixtures-poc.md`, ruled GO) keys a declared fixture without a
trace, so a declaration for each of these closes it for that fixture. Until then each costs its full loaded run on
every push.

**LIVE, re-derived batch 209.** The 0.754.0 gate's line read 7 of 251 UNMAPPED: `check-24-adversarial-convergence
hermetic-runner implementation-join-yield procsub-staged-refusal-boot readset-skip-digest-mutants self-update-gate
subject-partition`. Three of the original ten left by declaration or trace (`adversarial-shard-merge-mutants`,
`remediator-shard-join-mutants`, `self-update-fixture-log-mutants`, and `review-shard-merge-mutants` by committed rows);
`hermetic-runner` joined. `readset_trace_add`
(`.githooks/pre-push:812-814`) stops re-tracing a fixture at three discards on one key, so they stay unmapped until a
declaration lands or their key changes; re-derived from the local map (`.git/ai-dlc-fixture-readsets.local`, the one the
hook reads), six of the seven sit at `#discards 1` under the key the deriver's current sha minted, so each will be traced
twice more before it is held, and `subject-partition` holds 45 local trace rows with no discard row while the committed
map holds none for it. One of the seven, `implementation-join-yield`, is now declared, so six remain. The same morning's trace also OMITTED `adversarial-shard-merge-mutants` (3701
stream drops), `foreground-budget-deny` (89), `hermetic-runner` (551) and `readset-skip-digest-mutants` (786), so the
untraceable set is wider than the two filed.

**OPERATOR RULING, batch 215: `hermetic-runner` is OUT of this entry's set.** It is the runner's own self-probe and
is undeclared by design. Measured at `31617801` (0.760.0): `self-update-gate` and the class-b four carry
`inputs.decl` (0.759.0), and `check-24-adversarial-convergence` plus its `-b`, `-c`, `-d` shards do (0.760.0);
`procsub-staged-refusal-boot` was sharded into `-boot`, `-boot-b`, `-boot-c` and NONE of the three is declared, nor
are `procsub-staged-refusal`, `-b`, `-c` (control: `implementation-join-yield` declared, an impossible name absent).
The six procsub directories are undeclared BY RULING (0.760.0's CHANGELOG: they read this repo's own history, and
pinned blobs failed I104, I113 and I65 as a second corpus), so their close path is a committed trace, not a
declaration. The 0.760.0 gate's line read 7 of 269 UNMAPPED: `hermetic-runner`, the six procsub directories and
`subject-partition`. The entry closes on the first push whose read-set line reports `hermetic-runner` as the ONLY
fixture UNMAPPED.

verify: manual -- close when a push's read-set line reports no fixture other than `hermetic-runner` UNMAPPED, by a trace or by a declaration.

**Re-derived batch 214 (0.760.0).** `check-24-adversarial-convergence` is declared (four shards). `procsub-staged-refusal-boot`
is sharded into three `.dist-only` directories and reported UNSANDBOXABLE: it stages pre-fix engines by
`git -C "$TREE_TOP" show <sha>:core/skills/ai-dlc-update/reconcile/<file>`, and committing the blobs under `core/` as
fixture data was built for the sibling `procsub-staged-refusal` and failed enforcement-map arms I104, I113 and I65 as a
second corpus. It leaves this list only by a committed trace; its three shards are three such traces. `hermetic-runner`,
`self-update-gate` and `subject-partition` are untouched here.

Moved here from BL-493 in batch 220, because its subject (the post-green trace step) is this entry's.
**Re-derived batch 219 (0.763.0).** The first half shipped: the deriver drops `--level debug`, the liveness window is
~10s, `readset-sandbox-root-clause` retries up to ten windows. A second defect in the same tracer, measured on this
box: a consumer's pre-push hook (`/Users/n8/git/graph/.githooks/pre-push`, pid 47147) survived its `git push` by 42
minutes with parent init, no client and no session, because the post-green trace step blocks on nothing that dies
with the push. It spawned one `log stream --level debug` subscription per fixture the whole time and held
`diagnosticd` at 30-50% CPU and `fseventsd` at 100% until the operator stopped it by its process group. The trace
step must hold its parent's pid and exit when that pid is gone; until it does, an orphaned hook is a load generator
nobody started on purpose. This stays open on the UNMAPPED receipt above; the orphan is a second subject and needs
its own receipt when the fix is built.

**The orphan subject's receipt, batch 220 (0.768.0).** Pid 47147 was the DETACHED trace subshell, not the hook's main
body, so a parent-pid tie is the wrong fix: the trace is detached so the push never waits. The fix is a wall-clock
ceiling (`readset_trace_ceiling`: 3x the listed fixtures' recorded durations, floor 600s, cap 20000s) enforced by a
watchdog that kills the deriver's own process GROUP, then writes `exit timeout` and releases the lock. It is a HANG
guard: the incident's 42-fixture list would get 7272s and was a slow, working trace. The fixture arm that holds it is
`readset-skip-b` (t1); the fenced receipt below runs under `set -uo pipefail` from the repo root. It launches the real
`readset_live_trace` from the pre-push pool block against a stub deriver that forks a sleeping grandchild and never
exits, at a 2s ceiling, and exits 0 only if the lock is released, the deriver and its grandchild are both gone, and
the status reads `exit timeout`. This receipt is the orphan subject's; the entry's operative `verify:` above stays the
UNMAPPED one.

| Subject | Exit |
|---|---|
| fix (b220-ceiling) | 0 |
| base 9800057e | 1 |
| ceiling computed, never enforced (watchdog exits without signalling) | 1 |

```
H="$PWD/.githooks/pre-push"; [ -f "$H" ] || exit 9; unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; W="$(mktemp -d)" || exit 9; sed -n '/# FIXTURE_POOL_BEGIN/,/# FIXTURE_POOL_END/p' "$H" > "$W/pool.sh"; T="$W/t"; mkdir -p "$T/core/scripts" "$T/core/fixtures/gamma" "$W/tmp" "$W/o/.log" && printf 'exit 0\n' > "$T/core/fixtures/gamma/run.sh" && printf '#!/bin/bash\nsleep 600 </dev/null >/dev/null 2>&1 &\necho "$!" > "$RC_GC"; echo "$$" > "$RC_DP"\nwhile :; do sleep 1; done\n' > "$T/core/scripts/derive-fixture-readsets.sh" && git init -q "$T" && git -C "$T" add -A && git -C "$T" -c user.email=r@r -c user.name=r commit -qm s || exit 9; printf 'gamma\n' > "$W/o/.trace"; : > "$W/o/.trace.held"; printf ok > "$W/o/gamma"; printf '  ok\n' > "$W/o/.log/gamma"; export RC_GC="$W/gc" RC_DP="$W/dp" AI_DLC_READSET_LIVE_TRACE=1 AI_DLC_READSET_TRACE_CEILING=2 TMPDIR="$W/tmp/"; cd "$T" || exit 9; . "$W/pool.sh" 2>/dev/null; readset_live_trace "$W/o" >/dev/null 2>&1; i=0; while { [ ! -s "$W/gc" ] || [ ! -s "$W/dp" ]; } && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i+1)); done; gc="$(cat "$W/gc" 2>/dev/null)"; dp="$(cat "$W/dp" 2>/dev/null)"; case "$gc$dp" in ''|*[!0-9]*) exit 9 ;; esac; kill -0 "$gc" 2>/dev/null || exit 9; lk="$GITDIR/ai-dlc-fixture-readsets.local.lock"; i=0; while [ -d "$lk" ] && [ "$i" -lt 150 ]; do sleep 0.1; i=$((i+1)); done; r=1; [ ! -d "$lk" ] && ! kill -0 "$gc" 2>/dev/null && ! kill -0 "$dp" 2>/dev/null && grep -qx 'exit timeout' "$READSET_LOCAL.status" && r=0; kill -KILL "$dp" "$gc" 2>/dev/null; exit "$r"
```

**Re-derived batch 220 (0.767.0 gate, then 0.768.0).** The 0.767.0 gate's line read **3 of 277 UNMAPPED**:
`fixture-git-env-seam ledger-status-vocabulary validator-fork-budget`. `self-update-join-gate`, which no `git.decl`
form can seed (it clones and walks 1483 commits of history), left the set because that gate's in-pool trace RECORDED
it. 0.768.0 declares `fixture-git-env-seam` (`git.decl seed`; sandboxed rc 0, 21 arms; dropping its `!` input fails W
and V) and `ledger-status-vocabulary` (`git.decl seed`; sandboxed rc 0, 11 assertions; dropping `templates/` fails I22
and I119; stripping the sentinel fires `REQUIRED input … never consumed`). **`validator-fork-budget` stays
undeclared**: sandboxed it counts 3327 forks against `FORK_BUDGET=3324`, unsandboxed 3323. Its headroom was 4 at
0.766.0 (3320) and 0.767.0's `READSET_KEYROWS` sentinel arm in I66 spent 3 of them, so the budget is at its edge
outside the sandbox too. The entry closes when that fixture leaves the UNMAPPED line, by a recorded trace or by a
declaration whose sandboxed fork count fits the budget.


## BL-495 — fixtures declare whole directories as inputs, so one edit re-keys fixtures that may never read it

**DEFECT.** The 0.764.0 gate ran 47 of 277 fixtures although the release changed one shipped script
(`core/scripts/hermetic-run.sh`), one fixture's `run.sh`, and new `.decl` files in eight fixture directories. A
fixture whose `inputs.decl` declares a directory is re-keyed by any edit under it, and 31 `inputs.decl` files declare
`core/` (14) or `core/scripts/` (17). How many of those fixtures actually read the file whose change selected them is
NOT measured: a name-reference heuristic is not a read, because some (the `enforcement-map-*` units, through
`validate-enforcement-map.sh`) read every file under `core/` by content.

The fix narrows each broad declaration to the files the fixture reads, and each narrowing is checked against a
read-set trace of that fixture. An under-declared fixture is skipped when a file it reads changes, silently, so the
narrowing must never be justified by a declaration count alone.

verify: manual -- close when every `inputs.decl` line declaring exactly `core/` or `core/scripts/` is either narrowed against a read-set trace of its fixture or carries a stated reason it reads that whole directory by content

**Re-derived batch 220 (0.767.0).** The count is 32 rather than 31: of 233 `inputs.decl` files, 15 carry a whole
line `core/` and 15 a whole line `core/scripts/` (`grep -lxE`, control `ZZ-never/` 0), and 2 more carry the REQUIRED
spelling `!core/scripts/`, which a pattern without the `!?` prefix does not see. The receipt was `sh exit 9`,
which scored nothing and, once BL-493 closed, left the ledger with no scorable receipt and failed the gate's
`backlog receipts` step (R2); it is now a manual close stating the condition, because no mechanical predicate can
tell a narrowed declaration from an under-declared one without the trace.

## BL-497 — nothing joins a fixture's `inputs.decl` against its read-set trace, so an under-declared fixture skips silently

**DEFECT, filed at batch 221** as BL-495's residue, by the 0.771.0 tip adversary, measured at `4a4022e9`. BL-495 says
no mechanical predicate can tell a narrowed declaration from an under-declared one without the trace; the trace
exists for most fixtures, and nothing joins the two. Joining each declared fixture's `inputs.decl` against its own
rows in `.ai-dlc-fixture-readsets.tsv` (tracked paths outside the fixture's own directory) found **110 of 182**
traced declared fixtures reading at least one tracked file their declaration does not cover, **1927** paths in all.
Much of it is root noise (`.gitignore`, `package.json`); `agent-definition-render` alone reads 59 `core/scripts/*`
files it does not declare. An under-declared fixture is skipped when a file it reads changes, and its verdict-store
pass is reused, which is the failure BL-495 warned narrowing could introduce. Control in the same join: removing
`core-paths.sh` from `upstream-routing`'s declaration makes exactly that path appear.

The fix is the join as a validator (standalone, not an arm of `validate-enforcement-map.sh`, which the suite pole
runs), with the root-noise class enumerated and its false-positive set measured before it ships, then each real
gap declared. The map is stale for fixtures changed since its last derivation, so a row naming a file that no
longer exists is the map's, not the declaration's.

verify: manual -- close when a validator joining each declared fixture's inputs.decl against its committed read-set rows reports no uncovered tracked read outside an enumerated noise class, and every reported gap is declared

