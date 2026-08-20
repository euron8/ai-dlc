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
adopted this must not have its gate wedged by a mechanism it has not adopted. Rules 1, 2, 3, 5 and 6
of the grammar are checkable without this file; only rule 4 — *`kind` comes from a declared closed
set* — depends on it, and rule 4 has no enforcer today, so it stays unenforced whatever this file
says. See the `kind:` note below before you spend effort on that half.

## The grammar of this file

**Areas are declared as one `areas:` block.** The header sits at column 0 on a line of its own,
and every area is indented exactly two spaces beneath it:

    areas:
      _bmad-output/brainstorming
      _bmad-output/test-artifacts

`scripts/ai-dlc/artifact-path-config.sh` is the ONE reader, and it extracts this file and core's
grammar with the same expression, so the two cannot disagree about what an area is. Any other
spelling — `area: <path>` one per line, a bulleted list, an entry indented by one space or four —
extracts NOTHING. **The failure is silent in the worst direction**: the migration and the pre-push
validator go on reporting your area as INFERRED, printing the same "declare it in your own file"
remedy, with no sign anywhere that the declaration you wrote was unreadable.

**The reader scans the WHOLE FILE for a column-0 `areas:`, not only the fenced block below.** Two
such blocks are both read and their entries unioned. That is why the worked example at the end of
this file is indented — an indented `areas:` is inert and cannot leak into your real declaration.
De-indent it when you copy it.

An area is a path relative to the project root, and it must be DURABLE: it never moves and never
carries a sprint token itself. It is the directory that will hold `s<N>/`.

**`kind:` lines are read by nothing.** Rule 4 — *`kind` comes from a declared closed set* — has no
enforcer in the shipped toolchain, so a kind set here is a record for this project's own readers
and is not an input to any check. Declare them if they are useful to you; do not expect a gate to
hold them. `#` comments and blank lines are ignored throughout.

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

Replace the block below with an `areas:` block in the form above. If this project adds nothing to
what core declares, leave the literal `none` — an undeclared set and an empty one must not look
the same, which is why silence is not a legal answer here.

```
none
```

## A worked example, for reference only

Delete it or adapt it — it is prose here, not part of the block above, and nothing reads it.

    areas:
      docs/evidence
      test-results

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
