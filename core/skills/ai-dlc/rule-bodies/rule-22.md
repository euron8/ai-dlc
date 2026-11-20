### Rule 22 -- Pause-point resume MUST re-read the step file

This file is the full text of Rule 22 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

When a pipeline pause point (Rule 3(a)-(d)) receives human input and
the lead resumes execution, the lead's FIRST action MUST be a `Read`
tool call for the current step file. The lead MUST then enumerate the
remaining numbered sections in output before executing any of them.

This rule generalizes Rule 21's principle to mid-step resume. The
step file is the authority for what remains, not the lead's memory.
"Proceed" after human commentary means "continue the step sequence,"
not "skip to completion." Violation: Rule 4 (every section must
complete). Gate FAILS on detection at retro.
