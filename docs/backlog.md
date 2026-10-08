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

## BL-485 — `review-shard-merge-mutants` is the suite pole at 66 serial mutants in one unit

**DEFECT, filed at batch 205 by operator instruction.** The pre-push suite is pole-bound: wall clock
tracks the single longest DIRECTORY, and `core/fixtures/review-shard-merge-mutants/run.sh` is that
directory at every width. The durations record in the main checkout reads 1481s loaded against 1094s
for the next unit (`sort -k2 -nr .git/ai-dlc-fixture-durations | head -2`), so every push that selects
it pays 22 minutes whatever else it selects, and a selective push that touches
`merge-review-shards.sh` pays the same as a full one. The battery drives 66 `mutant` call sites
serially through one `run.sh` (`/usr/bin/grep -c '^ *mutant ' core/fixtures/review-shard-merge-mutants/run.sh`
= 66; the impossible-token control reads 0). Its own header records the shape: arms x mutants,
serially, and a loaded cost that went 731s to 1738s in one change.

The remedy is the one `fold-architect-ledger-join-mutants-{,b,c}` already carries: partition the
mutant set across sibling directories, each a `run.sh` the pool dispatches as its own unit, with the
partition declared once and joined against the `mutant` lines so a mutant added to the battery and
dealt to no shard fails the join (that battery's `[J0] coverage join` arm). Three shards of 22
bring the pole to roughly a third of 1481s loaded; the next pole is then
`gate-adjudication-mutants` at 1094s, which is the same shape and the same remedy. Each shard
carries its own unmutated control and the probe-bypass arm, exactly as the model does, and each is
a new fixture directory (read `.claude/rules/fixture-ship-decl.md` before creating one; the model
shards are `.dist-only`, so these will be too).

verify: sh d=core/fixtures; [ -f "$d/review-shard-merge-mutants/run.sh" ] || exit 9; n="$(ls -d "$d"/review-shard-merge-mutants*/ 2>/dev/null | wc -l | tr -d ' ')"; [ "$n" -ge 3 ] || exit 1; for s in "$d"/review-shard-merge-mutants*/; do grep -qE 'coverage join|J0' "$s/run.sh" || exit 1; done; exit 0

## BL-477 — `tools.decl` cannot name `node`, which blocks plan action 3

**BLOCKER.** Carried from the 0.746.0 adversary passes. `readset_declared` in `.githooks/pre-push` resolves each `tools.decl` name against
`READSET_TOOL_DIRS` (`/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`), and `core/scripts/hermetic-run.sh` refuses a
name that resolves in none of them (exit 2). On this box `node` is `~/.nvm/versions/node/v24.14.0/bin/node`, outside every one of
those directories, so a declaration naming `node` is unresolvable and the nine node fixtures of plan action 3 cannot be declared.
**Waiting on an operator ruling.** Options: an absolute path in `tools.decl` keyed by content hash (recommended; the runner's
bare-name rule and the hook's resolver both change), add the nvm directory to the fixed dirs (reintroduces a per-user key), or
reorder action 3 so the node fixtures go last.

The receipt seeds a one-fixture repo with `inputs.decl` = `x.txt` and `tools.decl` = `node`, runs the shipped runner with
`--key-only`, and requires a key row whose path ends in `/node`. Scored at 951678b5: exit 1 (the runner exits 2, `declared tool node
resolves in none of`). It exits 9 when `node` is not on the receipt's own PATH or the hook or runner cannot be read.

verify: sh H=.githooks/pre-push; S=core/scripts/hermetic-run.sh; [ -f "$H" ] && [ -f "$S" ] || exit 9; W="$(mktemp -d)" && W="$(cd "$W" && pwd -P)" || exit 9; unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; git init -q "$W" || exit 9; mkdir -p "$W/.githooks" "$W/core/fixtures/fx" "$W/scripts/ai-dlc" || exit 9; cp "$H" "$W/.githooks/pre-push" && printf 'exit 0\n' > "$W/core/fixtures/fx/run.sh" || exit 9; command -v node >/dev/null 2>&1 || exit 9; echo x > "$W/x.txt"; printf 'x.txt\n' > "$W/core/fixtures/fx/inputs.decl"; printf 'node\n' > "$W/core/fixtures/fx/tools.decl"; git -C "$W" add -A >/dev/null 2>&1; O="$(bash "$S" --root "$W" --key-only fx 2>/dev/null)" || exit 1; printf '%s\n' "$O" | cut -f1 | grep -q '/node$'

## BL-478 — a declaration in distribution coordinates does not resolve on a consumer

**DEFECT.** Carried from the 0.746.0 adversary passes. `inputs.decl` paths are project-root-relative and are copied from that root.
The distribution holds `core/scripts/x.sh`; an installed consumer holds `scripts/ai-dlc/x.sh` (`install.sh` splits `core/scripts/` to
`scripts/ai-dlc/`). A declaration written for this tree names a file absent on a consumer and the runner exits 2 `declared file
absent`. Inert while zero declarations ship. A path-mapping rule, one table shared by the runner and the hook, must land before any
real declaration ships.

The receipt builds a consumer-layout tree holding only `scripts/ai-dlc/x.sh`, declares `core/scripts/x.sh`, and requires the
runner's `--key-only` rows to carry `scripts/ai-dlc/x.sh`. Scored at 951678b5: exit 1.

verify: sh H=.githooks/pre-push; S=core/scripts/hermetic-run.sh; [ -f "$H" ] && [ -f "$S" ] || exit 9; W="$(mktemp -d)" && W="$(cd "$W" && pwd -P)" || exit 9; unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; git init -q "$W" || exit 9; mkdir -p "$W/.githooks" "$W/core/fixtures/fx" "$W/scripts/ai-dlc" || exit 9; cp "$H" "$W/.githooks/pre-push" && printf 'exit 0\n' > "$W/core/fixtures/fx/run.sh" || exit 9; echo ok > "$W/scripts/ai-dlc/x.sh"; printf 'core/scripts/x.sh\n' > "$W/core/fixtures/fx/inputs.decl"; git -C "$W" add -A >/dev/null 2>&1; O="$(bash "$S" --root "$W" --key-only fx 2>/dev/null)" || exit 1; printf '%s\n' "$O" | cut -f1 | grep -qx 'scripts/ai-dlc/x.sh'

## BL-479 — `tools.decl` naming `git` is keyed on the xcrun shim while the hook keys git's real exec-path

**NOTE.** Carried from the 0.746.0 adversary passes. `readset_tools` keys git from `git --exec-path`, the binary that runs. The
declared-tool resolver walks `READSET_TOOL_DIRS` in order and finds the `/usr/bin/git` xcrun shim first, so a fixture declaring `git`
is keyed on the shim. Inert while zero declarations ship.

The receipt runs the shipped runner with `--key-only` on a fixture declaring `git` and requires a row for the exec-path binary
(`env -u DEVELOPER_DIR -u GIT_EXEC_PATH /usr/bin/git --exec-path`). Scored at 951678b5: exit 1, the row is `/usr/bin/git`.

verify: sh H=.githooks/pre-push; S=core/scripts/hermetic-run.sh; [ -f "$H" ] && [ -f "$S" ] || exit 9; W="$(mktemp -d)" && W="$(cd "$W" && pwd -P)" || exit 9; unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; git init -q "$W" || exit 9; mkdir -p "$W/.githooks" "$W/core/fixtures/fx" "$W/scripts/ai-dlc" || exit 9; cp "$H" "$W/.githooks/pre-push" && printf 'exit 0\n' > "$W/core/fixtures/fx/run.sh" || exit 9; XP="$(/usr/bin/env -u DEVELOPER_DIR -u GIT_EXEC_PATH /usr/bin/git --exec-path)" && [ -x "$XP/git" ] || exit 9; echo x > "$W/x.txt"; printf 'x.txt\n' > "$W/core/fixtures/fx/inputs.decl"; printf 'git\n' > "$W/core/fixtures/fx/tools.decl"; git -C "$W" add -A >/dev/null 2>&1; O="$(bash "$S" --root "$W" --key-only fx 2>/dev/null)" || exit 1; printf '%s\n' "$O" | cut -f1 | grep -qxF "$XP/git"

## BL-484 — role contracts carry no chunked-write instruction, and the advisor paragraph fires only at the first write

**DEFECT.** Filed by the consumer as `PC-S317-ROLE-CONTRACTS-CARRY-NO-CHUNKED-WRITE-INSTRUCTION-AND-THE-ADVISOR-PARAGRAPH-FIRES-ONLY-AT-FIRST-WRITE`,
at the operator's direction: every role contract tells its agent to write the deliverable in chunks and iteratively, and
to consult the advisor at that cadence. The consumer measured on its installed `0.743.0`; re-derived on `758c461d`, the
filing makes five claims.

- **Party seats never write early: DEAD on tip.** `architect.md`, `dev.md`, `pm.md` and `tea.md` have carried a
  byte-identical `## As a party seat — write early, close with one marker` section since `0.744.0`: header first with
  `Write`, one append per finding, one final `seat-complete:` line. No arm bound those four copies.
- **No other role has a write-early rule: SURVIVES.** Eleven of the 18 role files carry no write-early language at all
  (analyst, cis, code-reviewer-escalated, dev-escalated, gate-adjudicator, ops, pm-escalated, protected-path-editor,
  remediator, sm, ux). Adversary, code-reviewer and qa say "header first and append" inside one deliverable section only.
- **Zero of 18 carry `in chunks`: SURVIVES.** `grep -il 'in chunks'` over `core/team-roles/*.md` at `758c461d` returns 0.
  The consumer's receipt keys on that literal.
- **The advisor paragraph fires only at the first edit or write: SURVIVES.** The `I122` paragraph says "before your
  first edit or write, and again before you write your deliverable or verdict", which a read-heavy seat reaches late.
- **A plain join consumes a chunked file as finished: SURVIVES, and chunked writes make it common.** Without
  `--complete`, `wait-for-deliverable.sh` reports DELIVERED on the first non-empty write since the join armed. The
  consumer saw a cross seat's file DELIVERED at 1,678 bytes with the agent still running, before a 4,008-byte final
  write.

**The plain joins.** Twelve lead-side join sites under `core/skills/ai-dlc/steps/` pass no `--complete`:
`_dispatch-protocol.md:108`, `_gate-procedures.md:116`, `:219`, `:243`, `:895` and `:1074`, `handoff.md:30`,
`carry-over-evaluation.md:29`, `discovery.md:27`, `requirements.md:32`, `gate-validation.md:2203` and
`implementation.md:107`. Two more plain joins exist. `route.md:82` makes "the same call without `--complete`" for
any deliverable that is not a seat, shard or cross file. `rule-bodies/rule-24.md:52` joins the analyst part files
plainly and then `cat`s them into the canonical artifact. For all fourteen sites, no result path carries a partial,
so the plain join is safe and needs no edit. The completion rule below is what makes that true.

**FIX.** One paragraph, byte-identical in all 18 role files, one blank line after the `I122` advisor paragraph's closing
line:

> **Write your deliverable in chunks and iteratively, never in one write at the end.** The deliverable is the result
> file your brief names, never a subject file you were asked to read or edit; if your brief names no result file, you
> have nothing to chunk. Create it with `Write` FIRST, before you have verified anything, carrying its header; append
> to it or rewrite it after each finding, and finish with one rewrite whose header matches its body, before any
> completion line your deliverable section names. If your deliverable section names a completion signal, chunk at the
> result path and write that signal last. If it names none, chunk to the sibling draft path `<result>.draft` and land
> the result path only with your final whole-file `Write`, so no join ever reads a partial result; delete nothing.
> Where your deliverable section says the file is written once, write it once and complete, and chunk nothing. Where
> it says you append to an existing record, append, and never `Write` over it. If an `advisor` tool is available to
> you, also call it before the first chunk and before the final rewrite, in addition to the calls the paragraph above
> names.

The anchor rule: the paragraph replaces its own opener only where that opener occurs exactly once in the file. The four
party-seat sections' step 1 now cites the paragraph instead of restating it. The completion rule is what keeps the
plain joins safe. A role with a completion signal writes it last. A role without one never exposes a partial at the
result path. The write-once clause reconciles `gate-adjudicator.md`, whose constraint now reads "One write: the verdict
JSON or, as a shard, your part file, each complete, never a draft." Arm `I123` binds the paragraph. It must appear exactly once per role file,
byte-identical to the modal copy, directly after the `I122` closer, and nowhere else under `core/` outside
`core/fixtures/`. Arm `I124` binds the party-seat section across exactly those four files.

The receipt copies the tracked tree to a `mktemp` directory and runs the COPY's own validator with `--arms I123`. The
unmodified copy must exit 0 (else 1). It then strips the paragraph from `ux.md` in the copy and renames the file to
`ux-bl484-probe.md`, a path the live tree must not hold (exit 9 otherwise, and exit 9 if the strip left the opener). The
run must exit non-zero (else 2) and name that path (else 3). Scored under `set -uo pipefail` on copies of the named
tree, with `tea.md` mutated on the arm's tree `793fb026`. Base `758c461d` read 1, because `--arms` selects nothing and
the clean copy fails. Tip read 0. Four mutants each read 1: 17 of 18, the advisor sentence removed, the whole block
re-wrapped, and the opener respelled "never in a single write". In every mutant, the copy's own `I123` named
`core/team-roles/tea.md`.

verify: sh v=scripts/validate-enforcement-map.sh; r=core/team-roles; p=ux-bl484-probe.md; [ -f "$v" ] && [ -f "$r/ux.md" ] || exit 9; [ ! -e "$r/$p" ] || exit 9; W="$(mktemp -d)" || exit 9; git ls-files -z | tar -c --null -T - -f - | tar -x -C "$W" -f - || exit 9; o="$(cd "$W" && bash "$v" --arms I123 2>&1)"; rc=$?; [ "$rc" -eq 0 ] || exit 1; awk '/^\*\*Write your deliverable in chunks and iteratively/{s=1} s&&/^$/{s=0; next} !s' "$W/$r/ux.md" > "$W/$r/$p" && mv "$W/$r/ux.md" "$W/ux.md.moved" || exit 9; grep -qF 'in chunks and iteratively' "$W/$r/$p" && exit 9; o="$(cd "$W" && bash "$v" --arms I123 2>&1)"; rc=$?; [ "$rc" -ne 0 ] || exit 2; grep -qF "$r/$p" <<<"$o" || exit 3; exit 0
