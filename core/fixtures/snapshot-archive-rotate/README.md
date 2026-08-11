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
| 8 | `--absorb` folds a stale snapshot into the same archive and creates no dated file |
| 9 | **REFUSAL** — a non-empty history with no `## ` heading is refused, not reported as nothing-to-rotate |
| 10 | **REFUSAL** — a git-ignored archive path is refused before anything is written |
| 11 | **CONTROL for 10** — the same tree with the ignore removed rotates normally, so 10 measured the ignore and not the tree |
| 12 | **MUTATION** — a splitter that drops one line refuses and writes nothing |

The mutation arm exists because the line-accounting refusal **cannot be reached from any
input**: it guards the splitter against itself. The only way to show it is live is to break the
splitter, and the arm carries the `cmp -s` guard that ledger-rotate's does — a `sed` matching
nothing would otherwise produce a "mutant caught" that caught nothing.

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
