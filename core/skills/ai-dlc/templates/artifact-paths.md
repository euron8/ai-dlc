# Artifact kinds and areas

**This file is yours.** Core scaffolds it once and never overwrites it.

It declares the closed set of artifact **kinds** this project produces, and any **area** roots
beyond the ones core already knows about. The grammar those names slot into is core's and lives
in `.claude/skills/ai-dlc/artifact-path-grammar.md`:

```
<area>/s<N>/<kind>[-<subject>][-p<M>].md
```

## Why this is yours and the grammar is core's

Core can say that the directory is the only sprint slot, because that is a fact about how a
reader composes a path rather than about your project. **Core cannot know that this project
produces a `datastack-import-plan` or a `capital-model-review`** — the same split
`pr-classes.md` and `story-fields.md` already make, and for the same reason.

**An undeclared or `none` kind set is a WORKLIST line, not a failure.** A project that has not
adopted this must not have its gate wedged by a mechanism it has not adopted. Rules 1, 2, 3 and 5
of the grammar are checkable without this file; only rule 4 — *`kind` comes from a declared closed
set* — depends on it, and rule 4 is the only one that stays unenforced while this says `none`.

## The grammar of this file

One `kind:` line or one `area:` line per entry, inside the fenced block below. Names are
`[a-z][a-z0-9-]*` — lowercase, hyphen-separated, no sprint token, because a kind that carried one
would put the sprint back in the filename and defeat the point. `#` comments and blank lines are
ignored.

An `area:` is a path relative to the project root, and it must be DURABLE: it never moves and
never carries a sprint token itself. It is the directory that will hold `s<N>/`.

## Areas core already declares

You do not need to repeat these; declare only what this project adds.

```
_bmad-output/planning-artifacts
_bmad-output/implementation-artifacts
_bmad-output/retro-artifacts
_bmad-output/specs
_bmad-output/party-mode-transcripts
docs/retro
docs/reviews
docs/escalations
```

## The declaration

Replace the block below. If this project adds nothing to what core declares, leave the literal
`none` — an undeclared set and an empty one must not look the same, which is why silence is not
a legal answer here.

```
none
```

## A worked example, for reference only

Delete it or adapt it — it is prose here, not part of the block above, and nothing reads it.

    area: docs/evidence
    area: test-results

    kind: adversarial
    kind: repair
    kind: resolution
    kind: research-notes
    kind: carry-over-evaluation
    kind: discovery-context
    kind: architecture-context
    kind: retro
    kind: retro-draft
    kind: closeout-tables
    kind: next-inputs
