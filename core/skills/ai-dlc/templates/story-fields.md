# Derivable story fields

**This file is yours.** Core scaffolds it once and never overwrites it.

It declares which fields of a `sprint-status.yaml` story entry are DERIVED from the story
file that entry names, rather than hand-maintained in the envelope.
`scripts/ai-dlc/sprint-status.sh derive-stories` reads it.

## What the derive does with it

For every entry of the current sprint's `stories:` mapping, in **each canonical copy that
exists**, it resolves the story file that entry names, reads each declared field from that
file's YAML frontmatter, and writes the value back into the entry.

**It rewrites only the value portion of a line that is already there.** Field order,
indentation, inline comments, block scalars, pipeline-only fields, sprint-level keys and
every non-current-sprint block are left byte-verbatim. The envelope is hand-edited by six
different actors and a tool that reformats it is worse than the duplication it removes.

**A field the story file does not carry is not written and not invented.** The entry keeps
whatever it had, and that field simply contributes no comparison for that story.

## `status` is not declarable

`status` is always derived, whether or not you list it. It is the one field
`sprint-status.sh check-stories` reads — the mechanical half of gate-validation.md Check 5 —
and it is declared in `.claude/schemas/sprint-status.json`, which is core's. **A project must not be
able to declare its way out of the field core's own check depends on.** Listing it here is
harmless and redundant; omitting it changes nothing.

Everything else is yours, because core cannot know that this project's stories carry
`capital_path` or `gate_1_model`.

## What core can and cannot decide

Core owns the parse, the two canonical views, the story-file resolution, the frontmatter
read and the byte-verbatim write — all of it from artifacts core itself defines. **Core
cannot decide which of your story fields are derivable.** A field that is authored in the
envelope and only mirrored into the story file must NOT be listed here, and core has no way
to tell those two apart by looking.

## The exit codes, because two of them exist to stop a silent success

- **0** — every declared field compared and (in write mode) written; nothing drifted.
- **1** — `--check` only: at least one declared field DRIFTED. Every drifted key is listed
  and **nothing is written**.
- **3** — **matched ZERO story files.** Compared nothing because there was nothing to
  compare against. This is not clean.
- **4** — matched at least one story file and **some story got zero comparisons** — every
  declared field, including `status`, was unreadable for it. "Matched files but verified
  nothing" is the same failure as "matched no files", and every consumer implementation of
  this check has conflated the two at least once.

**An undeclared or `none` field list is a WORKLIST line and exit 0.** A project that has not
adopted this must not have its gate wedged by a mechanism it has not adopted.

## The grammar

One `field:` line per derivable field, inside the fenced block. Names are
`[A-Za-z_][A-Za-z0-9_]*` — the same shape the schema's story-field grammar admits. `#`
comments and blank lines are ignored.

## The declaration

Replace the block below with your fields. If this project derives nothing beyond `status`,
leave the literal `none` in place — an undeclared list and an empty one must not look the
same, which is why silence is not a legal answer here.

```
none
```

## A worked example, for reference only

Delete it or adapt it — it is prose here, not part of the block above, and the derive does
not read it.

    field: status
    field: priority
    field: effort
    field: acceptance_criteria
