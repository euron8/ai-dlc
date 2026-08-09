# Item 22 — a stale path in a layer entry body: what the derivation measured

**Status: DERIVATION DONE, no release.** The item's stated premise is REFUTED and the check it
implies is refuted with it. What replaces both is narrower, has an empty measured false-positive
set, and reuses two declarations that already exist and are already single-homed.

Read this before writing any code for item 22. Everything below was measured read-only against the
reference consumer at `/Users/n8/git/graph`, 2026-08-09.

---

## The report, quoted rather than paraphrased

The consumer's own words, `_bmad-output/ai-dlc-update/reconcile-log-20260808T141706Z.md`, under
*Still open, deliberately*:

> `tea-consumer.md:18` stale path (no detector claims it).

That is the whole report. **The plan's gloss — "an entry body naming a path that no longer
resolves" — is the plan's, not the consumer's, and it is wrong.**

## The citation, re-read at ground truth

`.claude/skills/ai-dlc/extensions/roles/tea-consumer.md`, body:

```
## Context Loading

Before starting any work, read these files in order:

1. `_bmad-output/planning-artifacts/prd.md`
2. `_bmad-output/planning-artifacts/stories/`  (the sprint's story files)   <- line 18
3. `docs/coding-conventions.md`
```

**All three paths EXIST.** Measured with the directory listing as the control: the flat
`_bmad-output/planning-artifacts/stories/` holds **50** residual files, last touched by
`15c890eb3 chore(artifact-paths): migrate the story corpus onto the s<N>/ slot`, while the live
corpus is **233** `_bmad-output/planning-artifacts/s<N>/stories/` directories running to `s299`.

So the path resolves and points at the wrong corpus. **A role following this entry literally reads
50 files from up to 24 sprints ago and none of the sprint it is working.** That is worse than a
dangling path, which at least fails loudly.

## Why a resolver is the wrong check, with numbers

The obvious implementation — resolve every path-shaped token in an entry body — was measured over
all **43** layer entries in the consumer's `extensions/` and `overrides/`:

```
path-shaped tokens in entry BODIES        309
  resolve from the repo root              152
  do NOT resolve                          157   <- the false-positive set
distinct non-resolving tokens              79
```

Every one of the 157 that was inspected is legitimate. The three classes, with their leaders:

- **core-relative names** — `steps/retro.md` (8), `steps/implementation.md`, `SKILL.md` (3). These
  resolve inside core, not inside the consumer, which is the whole point of a `hooks:` target.
- **skill-relative names** — `overrides/SKILL__Rule-8.md`, `extensions/`, `extensions/README.md`.
- **bare basenames used as labels** — `sprint-status.yaml` (8), `compaction-log.md` (8),
  `bug-analysis.md` (6), `gate-log.md` (4), `audit-rule-files.sh` (4).

**So a resolver scores 157 false positives and MISSES its own subject**, because
`_bmad-output/planning-artifacts/stories/` is in the 152 that resolve. It is the unmeasured lint
the item itself warned against, and the measurement is what turns that warning into a refusal.

## The corpus that IS tractable

Narrow to path tokens under the artifact area — the roots
`artifact-path-grammar.md` already declares and `artifact-path-config.sh --scan-roots` already
resolves:

```
tokens under the artifact area, in entry bodies    27 distinct (36 occurrences)
entries carrying at least one                      13 of 43
```

That is small enough to enumerate by hand, and it was. Three findings, and **zero false
positives**:

| entry | token | why it is wrong |
|---|---|---|
| `extensions/roles/tea-consumer.md` | `_bmad-output/planning-artifacts/stories/` | the story corpus, restated off the declared template |
| `extensions/steps-domain/…carry-over…` | `_bmad-output/planning-artifacts/s<N>-carry-over-evaluation.md` | sprint token in a BASENAME (grammar rule 2) |
| `overrides/…config-integrity…` | `_bmad-output/implementation-artifacts/config-integrity-snapshot-s<N>.json` | sprint token in a BASENAME (grammar rule 2) |

**The same tree carries the conforming spelling as its own control**: another entry writes
`_bmad-output/planning-artifacts/s<N>/stories/` correctly. The consumer's layer holds both forms,
so the check discriminates rather than firing on a style.

The other 24 tokens are all correct and all would survive: area-root durables
(`prd.md`, `carry-over-backlog.md`, `bug-analysis.md` — which item 25 deliberately left at the
root), `_bmad-output/` root singletons the grammar explicitly does not govern
(`pipeline-snapshot.md`, `audit-anchors.md`, `.audit-watermark`), correctly-slotted
`s<N>/` prescriptions, and glob forms (`_bmad-output/**`, `*test-strategy*`).

**Note that existence is uncorrelated with correctness here.** Of the 27, ten do not exist and are
all fine — placeholder (`s<N>/…`) and glob forms. The one real story-corpus defect exists. Any
check keyed on existence gets both directions wrong.

## Which detector is missing, exactly

There is a 2×2 and one cell is empty. That is what "no detector claims it" means.

| | **prescriptions** (paths written in prose) | **real filenames** |
|---|---|---|
| **core's files** | I82, in `validate-enforcement-map.sh` | — |
| **a consumer's files** | **NOTHING** | `validate-artifact-paths.sh`, every push |

- **I82** holds core's own prescriptions to the grammar. Its corpus is derived and it is
  `core/skills/ai-dlc/steps/*.md`, `core/skills/ai-dlc/*.md` and `core/team-roles/*.md`. A
  consumer's layer entries are not in it and cannot be — that invariant runs in this repo only.
- **`validate-artifact-paths.sh`** reads REAL tracked filenames. `tea-consumer.md`'s own path
  conforms; the stale path is *inside* it, so this reader is looking at the wrong thing.
- **I84** declares the story corpus location exactly once
  (`core/schemas/sprint-status.json` → `story_file.stories_dir` =
  `_bmad-output/planning-artifacts/s{sprint}/stories`) and bans any shipped PROGRAM from restating
  an area-qualified story path. Its corpus is core's shipped programs. A consumer's layer entry is
  neither a core file nor a program.

**So the consumer's own prescriptions are the third corpus, and nothing reads them.** The report is
exactly right and the gap is one cell wide, not a new category of check.

## What to build, and the one thing it needs first

A new clause in the **`LC-R` family** — *cross-references into the rendered rulebook*, which is
already the family for "a reference in a layer entry must resolve". Next free ids, derived:
clause **`LC-R4`**, code **`W11`**, `contract_version` **17 → 18**, `subject: any`, `level: WARN`,
`prose_home: core/skills/ai-dlc/extensions/README.md`,
`enforcer: core/scripts/validate-layer-entries.sh`.

**WARN, not ERROR, and the reason is measured**: it fires on 3 entries on a consumer that has done
everything core asked, and its remedy is an edit to prose the operator owns. An ERROR would wedge a
pull over a reading, which is the failure `validate-artifact-paths.sh`'s own header records paying
for.

Two arms, each reusing a declaration that already exists:

1. **the sprint-token arm** — a path under a scan root whose basename carries a sprint token
   outside the reserved `s<N>/` slot;
2. **the story-corpus arm** — an area-qualified story path that is not the schema's
   `stories_dir` template with its slot substituted.

**AND THERE IS A FORK TO RESOLVE BEFORE ARM 1 CAN SHIP, which is the thing this derivation found
that the item did not name.** There are TWO sprint-token expressions, they differ, and the
difference is load-bearing:

- `artifact-path-config.sh --token-re` is `(^|-)(s|S|sprint-)[0-9]+($|[-.])` — **digits only**,
  correct for real filenames, which is all its callers read.
- I82 defines its own, wider, covering the placeholder forms `<N>`, `N` and `*`, because it scans
  PRESCRIPTIONS.

**Entry bodies are prescriptions.** Both of the sprint-token findings above are written `s<N>`, so
the shipped `--token-re` matches NEITHER of them: a check built on it would return a clean zero on
its own subject. The placeholder-aware predicate must therefore be hoisted into
`artifact-path-config.sh` — which its own header names as the single home of the sprint-token
expression, and which already exists precisely because three programs had grown byte-identical
copies of the extraction beside it — with I82 changed to consume it rather than define it.

Ship order follows from that: **hoist first, then the clause**, because the clause has no working
predicate until the hoist lands. A clause shipped on the digits-only expression would pass on the
reference consumer and read exactly like a clean layer.

## What this does NOT propose

- **No general stale-path detector.** The 157-token measurement is the refusal, and it should be
  quoted the next time one is proposed.
- **No existence check of any kind**, for the reason in the note above.
- **No change to `validate-artifact-paths.sh`.** Its subject is real filenames and it is right
  about them.
