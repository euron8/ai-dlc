# Artifact path grammar

**One home for where a pipeline artifact lives and what it is called.** Core prescribes the
grammar; the consumer declares its own areas and kinds in the file named by
`consumer_artifact_paths_file:` in `layer-contract.yaml`.

## Why this exists

**Currency is DECLARED, never searched.** The sprint a session is working is
`_bmad-output/implementation-artifacts/sprint-status.yaml`, key `sprint: N`, resolved by
`sprint-status.sh sprint-id`. Every place that instead asks the filesystem which artifact is
current is a second answer that can disagree with the first. The chain that works has three
links, and the middle one is where it breaks:

1. declared identity → `N`
2. a **TOTAL** function from `N` to a path
3. **no search**

**Flatness is not the defect. A filename grammar with no reserved slot for the sprint is.**
`docs/retro/` is the control that proves it: 299 files, flat, 288 of them matching `sprint-<N>.md`
exactly, six core programs reading it, and not one of them ever asks which is newest — each
composes the path from a sprint number it was given. Where link 2 is total, flat is fine. Where it
is partial, the reader must search, and search means mtime.

Two live defects were measured on the reference consumer, both of them link 2 being partial:

- **`ai-dlc-continue.sh` and `ai-dlc-acknowledge.sh` pick the live adversarial series by mtime
  across 135 files spanning 56 sprints in one never-pruned directory.** Both hooks carry the
  confession in their own comments, and both say the same thing about why it cannot be fixed
  where they stand: *"There is no naming-safe scope to add — series names take the sprint as a
  SUFFIX as well as a prefix."* That sentence is the case for this file, written by the release
  that could not fix it.
- **Check 6 of `validate-mandatory-rules.sh` globs `story-${SPRINT_N}-*.md`, and for sprints 298
  and 299 that glob matched ZERO files** — 73 stories in those sprints are spelled
  `story-S<N>-…` with a capital S. The loop body never ran, the failure counter stayed 0, and the
  check printed PASS. Control on the same directory in the same read: `story-297-*` matches 11.
  Two of the last four closed sprints had their Dev Agent Record compliance verified against
  nothing.

**And the inconsistency ORIGINATES IN CORE.** Measured across core's own shipped rule files:
**65 artifact paths prescribed, 41 conforming, 24 carrying a sprint token outside the reserved
slot**, in four positions and five spellings. The consumer's mess is core's grammar faithfully
executed. Fixing a consumer without fixing the prescription re-creates it next sprint.

## The grammar

```
<area>/                          area root = DURABLE, sprint-independent, never moves
  <name>.md                        prd.md, architecture.md, product-brief.md, active-epics.md
  s<N>/                          every artifact PRODUCED BY sprint N
    <kind>[-<subject>][-p<M>].md   architecture-adversarial-p2.md, retro.md
    stories/
      story-<M>-<slug>.md          the sprint comes from the DIRECTORY; <M> is the story index
```

Five rules, each mechanically checkable:

1. **`s<N>` is the only spelling of a sprint** — lowercase `s`, no zero padding, never `S<N>`,
   never `sprint-<N>`, never a bare number. **`s*` is the same slot quantified over every
   sprint**, and it is the ONLY wildcard the slot accepts. A cross-sprint read (discovery
   reading prior retros, a reviewer naming the retro class) is not a currency question, so it
   is not the search this grammar forbids — what is forbidden is asking the filesystem WHICH
   ONE IS CURRENT. Both spellings are whole components: `s*-retro.md` is a basename carrying a
   sprint token and rule 2 still rejects it.
2. **No basename may carry a sprint token.** The directory is the only sprint slot. That is what
   collapses four positions into one and makes conformance a single rule rather than a union of
   patterns.
3. **A file at an area root carries no sprint token and no `s<N>/` parent.** That is what makes it
   durable, and it is the predicate a close-out sweep has never had.
4. **`kind` comes from a declared closed set** — the consumer's, in the file named by
   `consumer_artifact_paths_file:`, the way `pr-classes.md` and `story-fields.md` already work.
   Core cannot know what artifacts this project produces.
5. **`p<M>` is the only pass marker** — no `pass<M>`, no `-pass-<M>`. Ordering stays `order_key()`'s
   job, never mtime's.

## Areas

An area is a durable root that never moves and never carries a sprint token itself.

```
areas:
  _bmad-output/planning-artifacts
  _bmad-output/implementation-artifacts
  _bmad-output/retro-artifacts
  _bmad-output/specs
  _bmad-output/party-mode-transcripts
  docs/retro
  docs/reviews
  docs/escalations
```

**The scan roots are WIDER than the areas, deliberately.** Rule 2 forbids a sprint token in any
basename core prescribes, including paths that are not sprint artifacts at all — a rotation
archive of a live log is not something sprint N produced, but `gate-log-archive-s<N>.md` is still a
sprint token in a filename and still makes a reader search for it. So I82 extracts under these
roots, which cover the areas above and everything beside them:

```scan-roots
_bmad-output
docs/retro
docs/reviews
docs/escalations
```

Two lists rather than one because they answer different questions — *where does an `s<N>/`
directory live* versus *what does the enforcement read* — and every area is asserted to sit under
a scan root, so widening one cannot silently orphan the other.

**`docs/retro/` is a net loss in isolation and is included anyway.** Its function is already
total, so moving it from `sprint-<N>.md` to `s<N>/retro.md` buys nothing on its own. It is in
because **a convention with a carve-out is two conventions**, and the cost is named here so the
sub-release that pays it knows it is paying a known price rather than fixing a defect.

## What is NOT an artifact path

The grammar governs artifacts a sprint PRODUCES. It does not govern:

- **Live logs and state at `_bmad-output/` root** — `pipeline-snapshot.md`,
  `pipeline-continuation-log.md`, `spawn-ledger.jsonl`, `pipeline-paused.flag`,
  `.context-sensor-state`. These are singletons whose whole point is that there is exactly one,
  and a sprint slot would create a second.
- **Rotation archives of those logs.** Rule 25(c) moves an epoch out of a live log; the epoch is
  not a sprint's product. Their current `-archive-s<N>.md` spelling is nonetheless in the
  migration ledger below, because it is a sprint token in a basename and the rule has no
  exceptions — it becomes `s<N>/<log>-archive.md`.

## What a syntactic check CANNOT catch, measured

`story-<id>-<slug>.md` and `<story-id>-review.md` both PASS rule 2 as written, because `<id>` is a
placeholder and the sprint is hidden inside it — and `story-<id>-` is the exact form Check 6's
glob broke on. **A syntactic check on the prescription cannot see a sprint number that a
placeholder conceals.** That is a real limit of the enforcement, not a gap in the rule: rule 2
still forbids the expanded form, and it is `validate-artifact-paths.sh` — the consumer-side
validator, which reads real filenames rather than prescriptions — that sees it. Stated here so a
later session does not read `artifact-path-grammar` as covering it.

**And that validator closes MOST of the gap, not all of it — measured, because the sentence above
used to claim all of it.** `<story-id>-review.md` expands to `S292-ff-s3-…-review.md` and is
caught. `story-<id>-<slug>.md` expands two ways, and only one of them carries a token anything can
see: on the reference consumer **761 of 1024 story files spell the sprint as a bare leading
number** (`story-297-1-slug.md`), which is character-for-character the `story-<M>-<slug>.md` this
grammar itself prescribes. No expression can separate those two without knowing which sprints
exist, and the whole corpus is deferred for that reason rather than half-judged. **The remaining
263 are visible and reported.** The release that moves `stories/` under `s<N>/` is what removes
the ambiguity, by taking the number out of the filename entirely.

## Enforcement

| where | what | status |
|---|---|---|
| core's own prescriptions | `validate-enforcement-map.sh` **I82** — every artifact path core prescribes conforms or is in the ledger below | **LIVE** |
| core's readers | readers compose a path from the declared sprint instead of searching | **LIVE** (10c) |
| an authoring agent | `SKILL.md` Rule 25 points here — READ AND FOLLOW before writing an artifact to a path the rulebook does not already name | **LIVE** (10c) |
| the consumer's tree | `scripts/ai-dlc/migrate-artifact-paths.sh` — dry run by default, `--apply` to move | **LIVE** (10d) |
| the consumer's tree, ongoing | `scripts/ai-dlc/validate-artifact-paths.sh` on the consumer pre-push — real filenames, every push | **LIVE** (10e) |
| all four of the above | `scripts/ai-dlc/artifact-path-config.sh` — the ONE reader of the blocks below, bound by **I83** | **LIVE** (10e) |

### Staying on the grammar: what the pre-push validator blocks, and what it does not

A migration is a one-time event and a convention with only a migration behind it has a half-life.
`validate-artifact-paths.sh` is the standing arm, wired into the consumer pre-push:

```
scripts/ai-dlc/validate-artifact-paths.sh            # verdict, as the hook runs it
scripts/ai-dlc/validate-artifact-paths.sh --report   # …plus the census, same verdict
```

**IT BLOCKS ON EXACTLY THE SET THE MIGRATION WOULD MOVE, and that scope is measured rather than
chosen for comfort.** On the reference consumer, immediately after the migration ran for real:

```
paths the migration would still MOVE            0     <- what a push blocks on
REFUSED by the migration, still non-conforming  48    45 ambiguous, 3 with no derivable area
under a stories/ directory, DEFERRED          1024    263 of them carry a visible token
```

Blocking on all 1072 would wedge first contact on a tree whose operator had already done
everything core asked, and the stories deferral is CORE's own decision — so a gate demanding it be
cleared demands something no core tool provides. A gate that fires on a tree nobody can clean is a
gate the operator turns off, and then nothing is enforced at all.

**NOTHING IS EXEMPTED BY A LIST.** Every non-blocking class is computed from the path itself:
a name that mentions two sprints, a sprint directory with no area to anchor it, a file under
`stories/`. There is no ledger to fall out of date and nothing that can be added to it by hand,
and an entry leaves its class the moment the obstruction is removed — rename an ambiguous file
badly and the next push blocks on it. All of them are PRINTED every run, with their reason and
their counts.

**The blocking set and the migration's move set are asserted EQUAL, in both directions**, by
the `artifact-path-conformance` fixture. Two programs reading one grammar do not fail
interestingly on their own; they fail by disagreeing, which leaves a push blocked on a path its
own stated remedy will not move.

**It probes itself every run.** The verdict rides on one expression resolved at runtime out of
this file, and an expression that matched nothing would report the same empty blocking set as a
fully-migrated tree. Six paths with known answers go through the same classifier first; a wrong
answer on any of them exits 2 rather than reporting a clean tree.

**An empty subject is NOT a pass.** A consumer with no tracked file under any scan root gets
`NOT-APPLICABLE` and exit 0 — failing a greenfield tree would make this grammar unadoptable, and
printing PASS over nothing is the zero-verification pass this repo keeps finding.

### Running the migration

**Dry run first, and read the refusals.** The script writes nothing without `--apply`.

```
scripts/ai-dlc/migrate-artifact-paths.sh              # plan + refusals, writes nothing
scripts/ai-dlc/migrate-artifact-paths.sh --apply      # git mv, verified per file
```

It moves with `git mv` only, never deletes, and never edits a file's content. Each move is
confirmed as *source absent AND destination readable AND sha256 identical to the pre-move
source*, per file — a count of moved files cannot see whether the right bytes arrived, which is
the only failure a migration really has. It aborts at the first failure, and a clean tree
(required for `--apply`) makes `git checkout -- .` a complete undo of a partial run.

**Rehearsed on a clone of the reference consumer before shipping**, 5145 tracked files scanned:

```
moves planned / applied / verified      2667  (git reported 2670 renames, 0 content changes,
                                               tracked file count identical either side)
REFUSED                                   48  45 ambiguous, 3 with no derivable area
DEFERRED (stories/, see below)          1001
destinations still carrying a token        0  <- the script's own self-check, both roads
re-run after applying                   rc=3  <- nothing left to migrate; it is idempotent
```

**Three things it will not do, each reported rather than guessed:**

- **A path naming two different sprints** (`story-S246-1-s11-...`, `gate-log-archive-s291-s292.md`)
  is REFUSED. Which sprint owns it is not derivable, and picking one silently files an artifact
  under the wrong sprint forever.
- **A sprint directory directly under a scan root that is not an area** (`_bmad-output/s177/`) is
  REFUSED. There is no area to anchor the slot to.
- **`stories/` is DEFERRED WHOLESALE.** The sprint is spelled two ways there and one of them is a
  bare number indistinguishable from the story index the grammar itself prescribes, so a run that
  took the directory would move `story-S298-1-…` and leave `story-297-1-…` — splitting one
  sprint's stories across two conventions. It moves in its own release.

**Areas it had to INFER are reported too, and the report sends you to YOUR file, not this one.**
This grammar declares eight. The reference consumer held sprint-tokened files in **nine** more —
the pre-run estimate said eight and the real run also found `_bmad-output/research`, on a single
file, which is the direction a count taken from a sample always misses in. They migrate under a
derived area and the report names each one, because inferring silently would leave the declaration
wrong while the tree moved on.

**Those nine are CONSUMER areas and do not belong in this file.** They go in the file named by
`consumer_artifact_paths_file:`, per the rule at the top of this page, and the migration READS
that file and joins its areas to the eight above — so declaring one is what stops it being
inferred. Before that join existed the report said *"the grammar file is INCOMPLETE and should
declare them"*, which named a core file that a pull overwrites; a consumer session followed it
literally and proposed adding nine consumer-specific areas to core. The remedy now names the
consumer's own path, resolved from the contract rather than restated.

**The pointer landed with the release that emptied the ledger, and that ordering was the point.**
A `SKILL.md` line saying "artifact paths follow this file" would, before 10c, have told an agent to
obey a grammar the step files it was executing broke in 24 places. An instruction that contradicts
the step being followed is worse than no instruction: the agent resolves it by guessing, and a
guess is a sixth spelling. The first agent told to follow this file is the first agent whose step
file already does.

**The readers that moved in 10c, and what each stopped doing:**

| reader | was | is |
|---|---|---|
| `ai-dlc-continue.sh`, `ai-dlc-acknowledge.sh` | `ls -t` over every adversarial series in one directory — 135 files, 56 sprints | glob inside `s<N>/`, `<N>` from `sprint-status.sh sprint-id`; no cross-sprint fallback |
| `validate-mandatory-rules.sh` Check 6 | a zero-match glob printed PASS | a zero match with stories on disk for other sprints FAILS, and the corpus count is the control |
| `validate-retro-evidence.sh` | `docs/retro/sprint-<N>.md` | `docs/retro/s<N>/retro.md`, with absent distinguished from uncited |
| `validate-spec-adoption.sh` | `docs/retro/sprint-*.md`, sprint parsed from the basename | `docs/retro/s*/retro.md`, sprint read from the directory |
| `validate-provenance-block.sh` | a retro-path regex whose silence exempted every retro | same regex on the new shape, with same-run probes both ways |
| `validate-draft-stamps.sh` | a missing artifact directory reported as PASS | `PASS WITH SKIPS`, naming what ran |

## Migration ledger

**EMPTY, and it is empty because 10c rewrote every entry rather than because anything was
excused.** What follows is what the list was for, kept because the ledger will be used again.

A path listed here is a prescription core makes TODAY that this grammar forbids — listed rather
than fixed when the readers cannot move in the same release, since rewriting a prescription while
a hook still globs the old shape breaks that hook on the next sprint's first artifact.

**The list is bound in BOTH directions by I82.** A prescription that is neither conforming nor
listed fails the build — that is the arm that stops a sixth spelling. A listed path that core no
longer prescribes ALSO fails the build, so the ledger cannot outlive what it excuses. It is a
ratchet, not a carve-out: it can only shrink. Both arms were re-proven against the empty list with
guarded mutants, because an empty ledger is exactly the shape in which a dead join and a satisfied
one read the same.

```legacy-artifact-paths
```

**What each became.** This is now the map 10d's migration script works from, and it is complete —
**the version 10a shipped was not, and it said it was.** Its header read *"so 10c has no design
work left to do"*, and it had no row for either log at `_bmad-output/` ROOT: those two sit under a
scan root but under no AREA, so no row in the table could be composed for them without a decision
nobody had made. The rule below is that decision, and it is one rule rather than a row per log.

| today | under this grammar |
|---|---|
| `planning-artifacts/s<N>-<artifact>-adversarial-p<M>.md` | `planning-artifacts/s<N>/<artifact>-adversarial-p<M>.md` |
| `planning-artifacts/s<N>-research-notes.md` | `planning-artifacts/s<N>/research-notes.md` |
| `planning-artifacts/ui-mockups-sprint-N.md` | `planning-artifacts/s<N>/ui-mockups.md` |
| `planning-artifacts/s<N>-epics/epics.md` | `planning-artifacts/s<N>/epics/epics.md` |
| `retro-artifacts/sprint-<N>-retro-draft.md` | `retro-artifacts/s<N>/retro-draft.md` |
| `specs/spec-s<N>-<slug>/SPEC.md` | `specs/s<N>/<slug>/SPEC.md` |
| `party-mode-transcripts/sprint-<N>-retro.md` | `party-mode-transcripts/s<N>/retro.md` |
| `docs/retro/sprint-<N>.md` | `docs/retro/s<N>/retro.md` |
| **every rotation archive**, wherever its live log sits — `implementation-artifacts/gate-log-archive-s<N>.md`, `pipeline-continuation-log-archive-s<N>.md`, `context-mode-protection-log-archive-s<N>.md`, `compaction-log-archive-s<N>.md` | `implementation-artifacts/s<N>/<basename>-archive.md` |

**Rotation archives all land in `implementation-artifacts/s<N>/`**, including the logs whose LIVE
copy sits at `_bmad-output/` root. One destination rule rather than one per log, and it agrees
with the only archive 10a did place. A second rotation inside one sprint appends an ordinal
(`-2`, `-3`) — never a sprint token, and never the span (`gate-log-archive-pre-s<N+1>.md` is
retired; an archive covering more than its own sprint states the span in its first line, where a
reader can act on it, instead of in a filename nothing parses).

Three spellings of one `docs/retro/` path (`sprint-<N>.md`, `sprint-N.md`, `sprint-*.md`) collapse
to one entry when they move, which is the whole argument in miniature.

**The story corpus was the one area 10c left flat, and the READERS have now moved onto the
grammar ahead of the files.** `planning-artifacts/stories/` was syntactically conforming — the
directory carries no sprint token — while the sprint hid inside the FILENAMES
(`story-<N>-<M>-slug.md`, `story-S<N>-<M>-slug.md`), which is precisely the limit §*What a
syntactic check CANNOT catch* documents.

`stories_dir` is now a TEMPLATE the schema owns (`sprint-status.json`), carrying the sprint slot,
with `{sprint}` substituted as a number for one sprint's corpus or as `*` for every sprint's.
Every program that needs the corpus resolves it from there; **I84 forbids a second copy**, which
is what the old literal had in four places. The story-id join is re-derived in the same direction
as everything else here: the sprint comes from the DECLARATION and the entry key contributes only
the index, so `story-302-1` resolves to `s302/stories/story-1-*.md` and no spelling of the sprint
in a basename can hide a story from Check 6 again.

**The FILES follow in the next release, and until they do a tree still holding them flat reports
FINDINGS rather than silence** — an unresolvable story entry is a finding by the schema's own
rule, and Check 6 fails with the migration command in its message. That direction is deliberate:
the previous shape of this defect was a check that verified nothing and printed PASS.
