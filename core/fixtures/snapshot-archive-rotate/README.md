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
| 12 | **MUTATION** — a splitter that drops one line refuses and writes nothing |

The mutation arm exists because the line-accounting refusal **cannot be reached from any
input**: it guards the splitter against itself. The only way to show it is live is to break the
splitter, and the arm carries the `cmp -s` guard that ledger-rotate's does — a `sed` matching
nothing would otherwise produce a "mutant caught" that caught nothing.

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
| rew | the history REWRITE fails after the archive append succeeded (`bigtail` under the same 8 KiB limit). An unlimited control run on a second copy first proves the sizing reaches the rewrite: the new history is over the limit, its preamble and tail each under it, the archive under it. Then: rc 1, the refusal names the rewrite, history and snapshot byte-identical, every pre-run history line still in the history or the archive, and the partial new history kept at the path the rotator prints |
| args | on the no-history path, an unknown option and an `--absorb` naming no file are both rc 2 |
| idem | absorbing the already-empty snapshot again leaves the archive byte-identical |
| ro | report-only `--absorb` (no `--apply`) on each of `nohist`, `floor` and `above`: rc 0, the rotator says what it would append, `git status --porcelain` is empty, the snapshot is byte-identical, and no archive exists |

The whole-content comparison is there because a marker grep alone is satisfied by an absorb that
copies ONLY the marker line — measured: `grep -E STALE "$ABSORB"` in place of `cat "$ABSORB"`
passed every arm and the receipt before it.

Mutants, each a one-line copy whose anchor must occur exactly once and be gone afterwards, driven
by the same arms after an unmutated control copy from the same directory passes them all:

| Mutant | Edit | Killed by |
|---|---|---|
| m1 | the truncate becomes `rm -f "$ABSORB"` | swap |
| m2 | `absorb_only` returns at once (absorb only on the rotation path) | floor |
| m3 | a history-absent exit inserted above the argument loop | args |
| m4 | the absorb path's `refuse_if_archive_ignored` becomes `:` | ign |
| m5 | `ai-dlc-continue.sh`'s `[ ! -f "$SNAPSHOT_FILE" ]` becomes `false` | neg |
| m6 | `ai-dlc-pause.sh`'s `[ ! -f "$SNAPSHOT_FILE" ]` becomes `false` | neg |
| m7 | the absorb's `archive_append … "$ABSORB"` is fed `grep -E STALE "$ABSORB"` instead (keeps only the marker line; the verified append still succeeds) | nohist |
| m8 | `archive_fail() {` becomes `archive_fail() { return 0` (every append guard reports and carries on) | unw |
| m9 | `absorb_only`'s report-only branch `if [ "$APPLY" -eq 0 ]` becomes `if false` (writes without `--apply`) | ro |
| m10 | the append's `\|\| archive_fail "the write failed"` deleted (write-status check) | wlate |
| m11 | the append's growth check deleted, both its numeric-operand guard and its comparison | wshort |
| m13 | m10 and m11 together, so only the `[ -f ]` guard is left | ulim |
| m12 | the history rewritten in place again, `cat preamble tail > "$HISTORY"` | rew |

m10 and m11 are not killed by `ulim`, and that is measured rather than overlooked. Over 88
`ulimit -f` appends (three body sizes, three limits, up to ten pre-fill offsets) every one of the
68 that failed both exited non-zero AND grew short, so on any input `ulimit -f` can build the two
checks cover each other and deleting either alone leaves `ulim` green. Each therefore gets a
subject the other cannot see, forced by a `cat` shim. There is a second reason the growth check
carries a numeric-operand guard: when the builtin `printf` fails, bash keeps the unwritten bytes
and the next `$( )` child flushes them into its output, so the size read back is not a number, and
`[ x -ne y ]` on it is an error an `if` reads as "the sizes match".

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
verified green from `/`, from its own directory, and from the repo root.
