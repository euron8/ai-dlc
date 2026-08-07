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
   never `sprint-<N>`, never a bare number.
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
still forbids the expanded form, and it is 10e — the consumer-side validator, which reads real
filenames rather than prescriptions — that catches it. Stated here so a later session does not
read `artifact-path-grammar` as covering it.

## Enforcement

| where | what | status |
|---|---|---|
| core's own prescriptions | `validate-enforcement-map.sh` **I82** — every artifact path core prescribes conforms or is in the ledger below | **LIVE** |
| core's readers | readers compose a path from the declared sprint instead of searching | 10c, not yet shipped |
| the consumer's tree | a migration, then a pre-push validator on real filenames | 10d / 10e, not yet shipped |

**Nothing points an AUTHORING agent at this file yet, and that is deliberate.** The obvious next
move — a line in `SKILL.md` saying "artifact paths follow `artifact-path-grammar.md`" — would tell
an agent to obey a grammar that the step files it is executing still break in 24 places. An
instruction that contradicts the step being followed is worse than no instruction: the agent
resolves it by guessing, and a guess is a sixth spelling. The pointer lands in 10c, in the same
release that empties the ledger, so that the first agent told to follow this file is the first
agent whose step file already does.

## Migration ledger

**Every path below is a prescription core makes TODAY that this grammar forbids.** They are
listed rather than fixed because the readers have not moved yet: rewriting a prescription while
`ai-dlc-continue.sh` still globs the old shape would break the hook on the next sprint's first
artifact. 10c moves readers and writers together; this ledger is what it empties.

**The list is bound in BOTH directions by I82.** A prescription that is neither conforming nor
listed fails the build — that is the arm that stops a sixth spelling. A listed path that core no
longer prescribes ALSO fails the build, so the ledger cannot outlive what it excuses. It is a
ratchet, not a carve-out: it can only shrink.

```legacy-artifact-paths
_bmad-output/context-mode-protection-log-archive-s<N>.md
_bmad-output/implementation-artifacts/gate-log-archive-s<N>.md
_bmad-output/implementation-artifacts/sprint-<N>-*.md
_bmad-output/party-mode-transcripts/sprint-<N>-retro.md
_bmad-output/pipeline-continuation-log-archive-s<N>.md
_bmad-output/planning-artifacts/s<N>-<artifact>-adversarial-p<M>.md
_bmad-output/planning-artifacts/s<N>-<artifact>-repair-p<M>.md
_bmad-output/planning-artifacts/s<N>-<artifact>-resolution-p<M>.md
_bmad-output/planning-artifacts/s<N>-architecture-context.md
_bmad-output/planning-artifacts/s<N>-bug-fix-oneshot.md
_bmad-output/planning-artifacts/s<N>-carry-over-evaluation.md
_bmad-output/planning-artifacts/s<N>-coe-adversarial-p<M>.md
_bmad-output/planning-artifacts/s<N>-discovery-context.md
_bmad-output/planning-artifacts/s<N>-research-notes.md
_bmad-output/planning-artifacts/ui-mockups-sprint-N.md
_bmad-output/retro-artifacts/sprint-<N>-closeout-tables.md
_bmad-output/retro-artifacts/sprint-<N>-next-inputs.md
_bmad-output/retro-artifacts/sprint-<N>-retro-draft.md
_bmad-output/specs/spec-s<N>-<slug>
_bmad-output/specs/spec-s<N>-<slug>/SPEC.md
_bmad-output/specs/spec-s<N>/SPEC.md
docs/retro/sprint-*.md
docs/retro/sprint-<N>.md
docs/retro/sprint-N.md
```

**What each becomes**, so 10c has no design work left to do:

| today | under this grammar |
|---|---|
| `planning-artifacts/s<N>-<artifact>-adversarial-p<M>.md` | `planning-artifacts/s<N>/<artifact>-adversarial-p<M>.md` |
| `planning-artifacts/s<N>-research-notes.md` | `planning-artifacts/s<N>/research-notes.md` |
| `planning-artifacts/ui-mockups-sprint-N.md` | `planning-artifacts/s<N>/ui-mockups.md` |
| `retro-artifacts/sprint-<N>-retro-draft.md` | `retro-artifacts/s<N>/retro-draft.md` |
| `implementation-artifacts/gate-log-archive-s<N>.md` | `implementation-artifacts/s<N>/gate-log-archive.md` |
| `specs/spec-s<N>-<slug>/SPEC.md` | `specs/s<N>/<slug>/SPEC.md` |
| `party-mode-transcripts/sprint-<N>-retro.md` | `party-mode-transcripts/s<N>/retro.md` |
| `docs/retro/sprint-<N>.md` | `docs/retro/s<N>/retro.md` |

Three spellings of one `docs/retro/` path (`sprint-<N>.md`, `sprint-N.md`, `sprint-*.md`) collapse
to one entry when they move, which is the whole argument in miniature.
