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

## BL-465 — the suite-pole guard compares only at pool widths someone hand-calibrated

**DEFECT.** Operator ruling, batch 202. `docs/suite-pole-baseline.tsv` holds rows only for pool widths 12 and 16, and
`scripts/validate-suite-pole.sh` SKIPs at any other width: a push at `AI_DLC_FIXTURE_JOBS=8` printed
`SKIP -- pool width 8 has no baseline row (widths with a row: 12 16)`. The operator's spec: every gated push records its
pole result keyed by the width it ran at, and the guard compares against that width's own recorded history, so any width
the operator uses is covered without hand calibration. A guard that skips at every width nobody calibrated reads exactly
like one that passed.

verify: manual -- close when a gated push at a width with no prior row records one, and the next push at that width compares against it instead of printing SKIP.

**The manual close above is the operative receipt** (`scripts/backlog-reverify.sh` reads only an entry's first `verify:`
line), and it stays so: only a real gated push exercises the hook's width sidecar. Beside it, the BEHAVIOURAL receipt for
the validator half, run from the repo root under `set -uo pipefail`. It drives `scripts/validate-suite-pole.sh` with the
hook's own argv (`--durations <gitdir>/ai-dlc-fixture-durations.last --record <gitdir>/ai-dlc-fixture-durations --jobs 4`,
cwd the root) in a fresh `mktemp` git repo whose baseline carries only a width-12 row: a near-solo coverage SKIP first;
three green runs at 500/520/510 that must each exit 0 with `CALIBRATING (n/3)`; three quiet runs at 300, admitted, for six
history rows; an ordinary 450 that must exit 0 against B=520 (a 3-row window would have collapsed B to 300 and failed it);
600, inside the band, exit 0; and 700, over the 692 ceiling, which must exit 1 with `GROWN`.

**Two rulings landed with the fix, batch 204, by the coordinator after the tip adversary measured B2 wrong.** B(W) is the
max of EVERY usable row at the width since its rows were last dropped -- not of the 3 most recent, which with admission at
or below B ratcheted one way: calibrated at 500/520/510 then 300x3, every ordinary loaded figure from 410 to 500 failed.
And a tracked row is a CALIBRATING SEED while its width has fewer than 3 history rows: compared and reported, recorded,
never a FAIL -- the operator ruled the hand-calibrated 12/16 rows the defect, and a seed that could block would stop the
history that replaces it from forming. A recorded run also consumes the width sidecar, so one published measurement is
one history row however often it is re-read.

**The re-push bypass is closed in the same branch.** `fixture_suite_step` records the content key before the pole step
runs, so a push red on the pole alone used to leave a key that let the re-push skip the suite and hand the guard
`/dev/null`. `pole_guard_step` now removes `$KEY_RECORD` when the validator exits 1, so the next push measures again --
which matters at every width now that the guard fires at every width.

Scored at batch 204 against the tip: base exit 1 (it prints `SKIP -- pool width 4 has no baseline row`), tip 0,
admits-above-B 1, K-window-restored 1, history-never-read 1, SKIP-kept 1, records-at-coverage-SKIP 1.

```
V="$PWD/scripts/validate-suite-pole.sh"; [ -f "$V" ] || exit 9; unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; R="$(mktemp -d)" && git init -q "$R" && G="$(git -C "$R" rev-parse --path-format=absolute --git-common-dir)" && mkdir -p "$R/core/fixtures/fx1" "$R/core/fixtures/fx2" "$R/docs" && echo 0 > "$R/VERSION" && echo 'exit 0' > "$R/core/fixtures/fx1/run.sh" && echo 'exit 0' > "$R/core/fixtures/fx2/run.sh" && printf '# history-band: 33\n# band: 15\n# jobs: 12\n# fixtures: 2\nfx1 100\n' > "$R/docs/suite-pole-baseline.tsv" || exit 9; L="$G/ai-dlc-fixture-durations.last"; D="$G/ai-dlc-fixture-durations"; hook() { o="$(cd "$R" && bash "$V" --durations "$L" --record "$D" --jobs 4 2>&1)"; c=$?; }; pole() { printf 'fx1 %s\nfx2 1\n' "$1" > "$L"; cp "$L" "$D"; echo 4 > "$L.jobs"; hook; }; printf 'fx1 10\n' > "$L"; printf 'fx1 10\nfx2 500\n' > "$D"; echo 4 > "$L.jobs"; hook; [ "$c" -eq 0 ] || exit 1; n=0; for s in 500 520 510; do n=$((n + 1)); pole "$s"; [ "$c" -eq 0 ] && grep -qF "CALIBRATING ($n/3)" <<<"$o" || exit 1; done; for s in 300 300 300; do pole "$s"; [ "$c" -eq 0 ] || exit 1; done; [ "$(awk 'END { print NR }' "$G/ai-dlc-suite-pole.history")" -eq 6 ] || exit 1; pole 450; [ "$c" -eq 0 ] && grep -qF 'pole fx1 450s against baseline fx1 520s' <<<"$o" || exit 1; pole 600; [ "$c" -eq 0 ] || exit 1; pole 700; [ "$c" -eq 1 ] && grep -qF GROWN <<<"$o" || exit 1; exit 0
```

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


## BL-480 — the local read-set map cannot see a directory's listing grow

**DEFECT, filed at batch 204's close.** `0.745.0` gives a directory row its `#listing:<sha>` value on the COMMITTED
digest path only. The local map (`ai-dlc-fixture-readsets.local`, written by `derive-fixture-readsets.sh --local-map`
through `readset_hash_rows`) still writes `-` for a directory, and `readset_local_validate` accepts a `-` row as a match
whenever the path is present. So a local row clears a stale record for a fixture whose directory gained a file the
trace never saw: the same false skip the tip adversary reproduced against the committed digest (`probe-grow.sh`,
`p5=|0`), on the older route. It predates `0.745.0`; the release left it alone by ruling, because changing the local
format without changing its validator in the same commit stops local clearing for every fixture with a directory row
(229 of 236 mapped fixtures at `60b467dc`).

Fix in one commit: the deriver's local path writes the listing, `readset_local_validate` compares it against `.now`,
and a world shaped like `readset-skip`'s `w9` but seeded through the local map proves the clear is refused, with `w10`
still clearing an unchanged directory. Build `w10`'s rows by calling the deriver's own `readset_hash_rows`, not by hand:
the tip adversary noted that today's `dirlocal` mutant disables the validator's `-` test and so cannot catch a deriver
that starts emitting listings on this path.

verify: manual -- close when a local-map world in which a traced directory gains a file runs its fixture, and a mutant restoring `-` on the local path is killed by that world alone.

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

verify: manual -- close when a push's read-set line reports none of these fixtures UNMAPPED, by a trace or by a declaration.

## BL-482 — a new fixture directory reruns nearly every fixture

**DEFECT, filed at batch 204's close.** 229 of 236 mapped fixtures carry the `core/fixtures` DIRECTORY row at
`60b467dc`, and the hook keys a directory row as its LISTING, so adding or removing any fixture directory reruns all of
them. Measured by the hermetic decision report (`docs/poc/hermetic-decision.md`, section 4): on the five release pairs
in fifteen that added or removed a fixture directory, the traced key selected 219-226 fixtures against 53-111 for a
declared key; on the other ten the two agreed within 5. `0.745.0`'s own gate was near-full for this reason.

Same report, section 2: `readset_tools` does not fingerprint a tool a fixture reaches only through a non-`.sh` call or
a non-standard PATH entry, so `node` is unkeyed for every fixture that needs it. `0.745.0`'s CHANGELOG states the
same fact from the other side (tools outside the fixed directory list are no longer keyed). Both close under the
hermetic program's declared keys (`tools.decl`; see `BL-477`), not by widening the traced key.

verify: manual -- close when adding one fixture directory to a tree reruns only the fixtures whose keys declare `core/fixtures/` itself.

## BL-483 — `pre-push-wall-clock.md` sits 11 bytes under the plan ceiling and cannot be rotated

**NOTE, filed at batch 204's close.** `docs/plans/pre-push-wall-clock.md` is 149989 bytes against `P8`'s 150000.
`0.745.0`'s first gate failed on it at 150022, and the release trimmed one paragraph to pass. `scripts/plan-rotate.sh`
refuses the file: its first `##` section declares no live sections in backticks inside a numbered list, so the
rotator cannot tell what is spent. The next edit to that plan of any size blocks the push. Fix: add the live-section
declaration, then rotate.

verify: sh f=docs/plans/pre-push-wall-clock.md; [ -f "$f" ] || exit 0; o="$(bash scripts/plan-rotate.sh "$f" 2>&1)"; grep -qF 'REFUSING' <<<"$o" && exit 1; [ "$(wc -c < "$f")" -lt 140000 ]
