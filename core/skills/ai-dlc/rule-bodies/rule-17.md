### Rule 17 -- Write large files in sections

This file is the full text of Rule 17 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

When creating or updating a file that exceeds ~200 lines, break the
write into multiple sequential operations. Single large writes risk
output token limits and timeouts that leave files incomplete. Applies
to all file types: planning artifacts, story files, code, tests,
reviews.
