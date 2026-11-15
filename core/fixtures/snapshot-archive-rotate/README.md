# snapshot-archive-rotate

Subject: `scripts/ai-dlc/rotate-snapshot-archive.sh` (`core/scripts/` in the distribution).

## What this asserts

That rotating `pipeline-snapshot-history.md` into one append-only archive **conserves every
substantive line into the conservation corpus**, and that each of the rotator's three refusals
can actually fire.

The acceptance arm is not "the archive exists". It is that
`git ls-files -z -- '*.md' | xargs -0 cat` — the corpus
`validate-snapshot-conservation.sh` builds — still contains every substantive line the history
held before the rotation. Writing the bytes and conserving them are different claims, and only
the second one is what Check 35 measures.

## Why that distinction is the whole fixture

Measured on the reference consumer, with 89 candidate lines and a floor of 40:

| corpus | destroyed | verdict |
|---|---|---|
| as-is | 17 | PASS |
| with `pipeline-snapshot-history.md` removed | **79** | **FAIL** |
| with all 158 dated `pipeline-snapshot.archive.*.md` removed | 17 | unchanged |

62 candidate lines live only in the history file. A rotation whose destination is outside the
corpus — git-ignored, or written but never staged — does not shrink a file; it destroys 62
lines of gate provenance and turns Check 35 red. Hence assertion 6 (the archive is staged) and
assertion 10 (an ignored destination is refused before anything is written).

## Why the seed looks over-built

Because a tidy seed hides the defect. On the reference consumer the live history matches
`^## ` **163 times, and those are not 163 entries**: an entry that archives a whole snapshot
pastes it in verbatim and brings the seven schema section headings with it, and one line is a
sentence that merely begins `## Deploy Baseline`. A rotator treating every `^## ` as its own
entry shreds archived snapshots into fragments — and conservation still passes, so nothing
would ever report it.

The seed therefore carries all three shapes: 18 plain entries, one entry holding a nested
verbatim snapshot with its own seven `## ` sections, and one prose line starting `## `. That
is 28 matches and only 21 cut candidates, which is what assertion 2 pins and assertion 5
proves the consequence of.

## Arms

| # | Arm |
|---|---|
| 0 | **SANITY** — the seed really holds the nested snapshot. Exits 2 as `FIXTURE BROKEN` otherwise, so no arm below can pass over the wrong shape |
| 1 | report-only default: exits 0, history byte-identical, archive not even created |
| 2 | 11 of 21 cut candidates move — the seven nested schema headings are excluded from candidacy |
| 3 | `--apply` writes, and the preamble H1 stays in the live file |
| 4 | **ACCEPTANCE** — 0 substantive lines absent from the corpus, beside a `/dev/null` control proving the zero is real |
| 5 | the nested verbatim snapshot's seven sections land wholly on one side, never split |
| 6 | the archive is staged, so `git ls-files` — which *is* the corpus — contains it |
| 7 | idempotence: a second `--apply` changes neither file; the header is seeded exactly once |
| 8 | `--absorb` folds a stale snapshot into the same archive — the archive's last N lines are byte-identical to a pre-absorb copy of the whole snapshot — leaves the snapshot present at 0 bytes, and creates no dated file |
| 9 | **REFUSAL** — a non-empty history with no `## ` heading is refused, not reported as nothing-to-rotate |
| 10 | **REFUSAL** — a git-ignored archive path is refused before anything is written |
| 11 | **CONTROL for 10** — the same tree with the ignore removed rotates normally, so 10 measured the ignore and not the tree |

The line-accounting refusal guards the splitter against itself and cannot be reached from any input; it is not asserted here.

## The absorb swap

route.md's fresh start is two acts: the rotator absorbs the stale `pipeline-snapshot.md`, then
the lead writes the new one, and a turn can end between them. `ai-dlc-continue.sh` (Stop) and
`ai-dlc-pause.sh` (UserPromptSubmit) both key "a pipeline is active" on the snapshot's
**existence**. A rotator that removes the snapshot turns both off for that window, so `--absorb`
truncates it to 0 bytes instead. It must also run on every path that is not a refusal, or the
lead's next write destroys the stale snapshot unarchived.

These arms drive the REAL rotator and the REAL hooks, each against a fresh copy of one seed
template (`seed.sh` builds `nohist`, `floor`, `above`, `nosnap`, `ignored` and `bigtail`):

| Arm | Asserts |
|---|---|
| swap | the hooks block and raise the flag BEFORE the call (precondition), and still do AFTER `--absorb --apply` |
| neg | a tree with no snapshot keeps both hooks silent |
| nohist / floor / above | absorb with no history, with exactly `--keep-entries` cut points, and above the floor. Each proves its path by the rotator's own verdict line, then asserts the marker is in the archive once, the archive's last N lines are byte-identical to a copy of the snapshot taken before the call (N = that copy's line count; each seeded snapshot carries several distinct lines, only one of them the marker), the snapshot is present at 0 bytes, and the archive is tracked |
| ign | an ignored archive on the no-history path: rc 1, snapshot byte-identical, no archive |
| unw | the archive path pre-created as a DIRECTORY (unwritable for any user, root included), on the no-history path and on the above-floor rotation path: rc 1, snapshot byte-identical to its pre-run copy, and on the rotation path the history byte-identical too. A directory is refused by the `[ -f ]` guard alone, so this arm cannot see the other two append guards |
| ulim | a REGULAR-FILE archive pre-filled to 40 bytes under an 8 KiB `ulimit -f` (inside a subshell with `trap '' XFSZ`, so it binds root too and the writer gets EFBIG instead of dying), on no history and on the rotation path: rc 1, the archive appended part-way, snapshot and history byte-identical. Kills the rotator that keeps only `[ -f ]`, which exits 0 and empties the snapshot |
| wlate | a `cat` shim on `PATH` writes every byte and then exits 1: rc 1, snapshot byte-identical, archive growth exact. Only the write-status check sees it |
| wshort | a `cat` shim writes all but the last byte and exits 0: rc 1, snapshot byte-identical, archive growth one short. Only the growth check sees it |
| rew | the history REWRITE fails under the same 8 KiB limit (`bigtail`). An unlimited control run on a second copy first proves the sizing: the new history is over the limit, its preamble and tail each under it, the archive under it. Then: rc 1, the refusal names the rewrite, history and snapshot byte-identical, NO archive (the new history is built before the append), every pre-run history line still in the history. Under the rename design the `cp -p` of the old history is the first write to fail, so the content write's own guards are owned by tlate/tshort |
| tlate / tshort | a `cat` shim acts ONLY on the temp write (the one call whose first argument ends `/preamble`): it writes every byte then exits 1 / drops one byte and exits 0. rc 1 before the archive append, history and snapshot byte-identical, no archive. Only the write's status check / size check sees each |
| rohist | a 444 history: rc 1 with NO archive created, history and snapshot byte-identical. Under root a 444 file is writable, so the arm prints `skip` rather than passing |
| rodir | a writable history in a 555 directory: rc 1 before any write, on a first and a second run, the archive never created, history and snapshot byte-identical. Under root a 555 directory is writable, so the arm prints `skip` |
| rosnap | a 444 snapshot on `--absorb` (no history): rc 1, the snapshot unchanged in size, and the refusal says it is archived but NOT emptied. Under root a 444 file is writable, so the arm prints `skip` |
| links | a symlinked history and a hard-linked history: each rc 1 naming the reason, before any write. The link is still a link and its target byte-identical; the history and its peer byte-identical; the snapshot byte-identical; no archive |
| mode | a 640 history rotates to the clean result and is still 640 after the rename; a peer file in the same directory is untouched. chmod means nothing on FAT, so this arm is about the host it runs on |
| atomic | an `mv` shim fails the rename WITHOUT calling the real `mv`: rc 1 naming the rename, history and snapshot byte-identical, and NO file left at the temp name. The only arm that can assert "no temp left": a killed run legitimately leaves one |
| sweep | a KILL-POINT SWEEP with `--absorb`, traced in the rotator's OWN shell: `BASH_ENV` sources a file that sets `set -T` and a DEBUG trap, so every simple command, including each one in an EXIT or ERR trap handler, is a numbered point — builtins, assignments, redirections, function calls, absolute-path and `command -p` externals, in the main shell and in every subshell. A counted unkilled run first: rc 0, the history equal to a clean rotation, T points numbered densely 1..T (219 at this release). Then, each in a fresh world with its own TMPDIR and counter, point N runs under `ulimit -f L` (SIGXFSZ ignored) and the trap SIGKILLs the rotator at point N+1; a plain re-run follows: rc 0, 0 pre-run history and snapshot lines missing from the tracked corpus (`git ls-files` `*.md`), the history equal to a clean rotation. L = 1 (1024 bytes) at every N, so a write of a longer file is cut part-way; L = 0 at every N from the point before the rename to T and at every 8th N below it, so a write is left empty. The last point is never killed and must complete clean at both limits. The sweep proves its reach: every scheduled run produced a verdict, a kill per limit lands ON `mv` and one after the rename, and at least one kill leaves a history or temp file of exactly 1024 bytes; the seed's history and the new history are each asserted over 1 KiB. The counter is an O_EXCL create (`set -C`), atomic when pipeline stages trace concurrently |
| staged | without `--absorb`, a `git` shim SIGKILLs the rotator at `git add` of the archive, after the rename; the control is that the archive is NOT tracked after run 1; the re-run lands on "nothing to rotate", rc 0, the archive tracked, the history equal to a clean rotation, 0 pre-run lines missing from the tracked corpus. The sweep cannot own this: with `--absorb` the re-run's absorb stages the archive itself, so a missing staging call on that path passes every kill point and fails only here |

Every shim arm asserts the shim's sentinel counted exactly one action, so an arm whose shim never
fired on its intended call cannot pass. A shim that kills sends SIGKILL to the rotator, so nothing
outlives the kill to finish the rename after it, and no watcher polls a process table.

The sweep runs on 12 workers (`KPAR`), job i on worker i mod 12, from N = T down with no barrier,
and a failing run stops every worker before its next job. The L = 0 window is scheduled from the
counted run's trace (the point before its first `mv`) and then checked: the first L = 1 kill that
found the new history already in place must lie above it, or the arm fails. Every killed run gets
its own plain re-run on its own world. No killed world is judged equal to the template and given
another run's result: a world whose bytes are the template's but whose re-run is refused (mode bits,
a `chflags uchg` file flag, a deny-write ACL) is invisible to `diff -r` and `ls -lAnR` (reading them
needs the BSD-only `ls -O` / `ls -e`). L = 0 is sampled below the rename because every point at both
limits was 90s and 18 workers were no faster than 12. The DEBUG trap reaches everything a PATH-shim
sweep reached, because every shimmed call is itself a simple command of the rotator's shell, so no
shim pass is kept.

**What the sweep does not reach.** The kill lands only between simple commands of the rotator's
own shell or of a child `bash` it starts plainly: the trap file leaves `BASH_ENV` set, so `bash -c`
and a bash helper script source it too. A child started as `bash --posix`, as `bash -p`, with
`POSIXLY_CORRECT` set, or under `env -i` does not source `BASH_ENV` and is untraced. Every command
in an EXIT or ERR trap handler is a kill point, whether it is written inline in the handler's
string or in a function the handler calls. This was measured on bash 3.2.57 and 5.2.15: a
3000-byte write inline in an EXIT handler is cut at 1024 bytes. The rotator's only trap,
`trap 'rm -rf "$TMPD"' EXIT`, is inline. A program that is not bash, or bash started as `sh` (sh, dash, zsh,
perl, python, awk, a compiled tool), runs to completion under the limit, so a kill between two of
its own writes to the history is never modelled. A pipeline stage or background job still running
when the kill lands is not killed with the rotator. A write of 1024 bytes or fewer is whole under
L = 1. The L = 0 sampling below the rename can miss a write-through BEFORE the rename whose recovery
separates an empty history from a partial one: L = 1 runs at that point, but leaves a partial
history, which that recovery handles.

| Arm | Asserts |
|---|---|
| args | on the no-history path, an unknown option and an `--absorb` naming no file are both rc 2 |
| idem | absorbing the already-empty snapshot again leaves the archive byte-identical |
| ro | report-only `--absorb` (no `--apply`) on each of `nohist`, `floor` and `above`: rc 0, the rotator says what it would append, `git status --porcelain` is empty, the snapshot is byte-identical, and no archive exists |

The whole-content comparison is there because a marker grep alone is satisfied by an absorb that
copies ONLY the marker line — measured: `grep -E STALE "$ABSORB"` in place of `cat "$ABSORB"`
passed every arm and the receipt before it.

The swap arm FAILS against the rotator that removed the snapshot (the one before truncation
existed), because the hooks go silent once the file is gone.

## Ships to consumers

Yes — no `.dist-only`. The subject is a script `install.sh` copies to every consumer, so it
fails all three `.dist-only` criteria in `.claude/rules/fixture-ship-decl.md`.

## Running it

```
bash core/fixtures/snapshot-archive-rotate/run.sh
```

Cwd-invariant: it locates the rotator by walking up for either layout marker
(`core/scripts/` or `scripts/ai-dlc/`) rather than resolving relative to itself, and is
verified green from `/`, from its own directory, from the repo root, and in an installed consumer.
