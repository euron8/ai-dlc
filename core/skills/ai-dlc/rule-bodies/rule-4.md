### Rule 4 -- No step may be skipped regardless of perceived simplicity

This file is the full text of Rule 4 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

When a step file is loaded via "READ AND FOLLOW", execute every
numbered section sequentially. Do not skip sections. Do not jump to
the next step file until the current step's execution sequence is
complete and its gate validation has passed.

"This is simple" is never a valid reason to bypass a step or
sub-step. A step that has nothing to do completes quickly — but it
MUST be loaded (Read tool call per Rule 21) and its execution
sequence MUST run. Skipping validation, Skill invocations, or gate
checks to save time or tokens is a pipeline violation. Violation
fails the next gate unconditionally.

The sequence is the step-file routing ("READ AND FOLLOW" directives
and `nextStepFile` in frontmatter), not your judgment: do not reorder
steps or jump ahead. Review every element of every artifact
exhaustively; do not summarize.
