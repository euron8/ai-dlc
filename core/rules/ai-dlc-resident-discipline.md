# Resident-context discipline (AI/DLC Rule 23)

NO `paths:` frontmatter, deliberately. Scoped rules load once per session and are NOT
re-injected after a compaction; unscoped ones ARE (`load_reason:"compact"`, measured on
CC 2.1.226). Adding `paths:` here silently disables this carrier.

It DUPLICATES `SKILL.md` Rule 23 rather than replacing it, so on a build with no rules
loader this file is inert and Rule 23 behaves as before.

**It is a carrier, not a precedence layer.** A rule file sits outside Rule 27's
`overrides/` > `extensions/` > core ordering entirely. If this project shadows Rule 23 in
`overrides/`, THE OVERRIDE WINS and the text below is stale for you — read the override.

**(a) No redundant re-loads.** Re-Read only the *current* step file. Do NOT re-Read a
completed step file or a planning artifact to "refresh" — that permanently duplicates it
into the working context. Query `pipeline-snapshot.md` for prior-step state instead.
`gate-log.md` and `pipeline-snapshot.md` are exempt: their re-read IS the verification.

**(b) Sliced re-read.** On a Rule 22 resume into a large step file whose earlier numbered
sections are complete, the mandatory `Read` MAY carry an `offset`. The Read call stays
mandatory — only its span narrows. Never slice past an incomplete section.

**(c) Offload high-volume observational Bash.** Large read-only output (test runs, gate
output, `git log`/`diff`/`status`, log scans) MUST go through `ctx_batch_execute` /
`ctx_execute`. Two hard limits: state-mutating commands (`git` commit/branch/merge, `gh`,
`chmod`, file writes) MUST use native Bash — a context-mode subprocess discards filesystem
changes and silently no-ops the mutation; and verbatim-load files (rule, step and role
files, schemas, snapshot, `gate-log.md`, escalations, story files) MUST NOT be routed
through `ctx_execute_file` / `ctx_batch_execute` / `ctx_index`, which drop directives.
`ai-dlc-protect.sh` hard-blocks that set.

Full text and exemptions: `.claude/skills/ai-dlc/SKILL.md`, Rule 23.
