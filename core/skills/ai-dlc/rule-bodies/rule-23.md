### Rule 23 -- Resident-context discipline

This file is the full text of Rule 23 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

Cache-read cost scales with the size of the working context times the
number of turns it stays resident. Every byte re-injected into context
is re-read on every subsequent turn until compaction. Three controls
keep the resident set lean without weakening step fidelity:

**(a) No redundant re-loads.** Re-Read only the *current* step file
(per Rules 21-22). The lead MUST NOT re-Read a completed step file or
a planning artifact to "refresh" — that permanently duplicates it into
the working context. The pipeline snapshot is the authoritative source
for prior-step state (per the Handoff Protocol); query it instead of
re-loading the producing artifact. State files the gate checks must
re-verify (`gate-log.md`, `pipeline-snapshot.md`) are exempt — their
re-read IS the verification. That exemption is conditional on their
staying small, which is not automatic. The snapshot is the most-read
file in the pipeline (every gate, every resume, every compaction
recovery) and carries the tightest Rule 25(d) threshold of any
artifact. Enforce its schema at each gate rather than letting it
accrete.

**(b) Sliced re-read of large step files.** When a Rule 22 resume
targets a large step file whose earlier numbered sections are already
complete, the lead MAY issue the mandatory `Read` with an `offset` to
the remaining sections rather than the whole file. The Read tool call
— the attention interrupt that defeats run-from-memory — remains
mandatory; only its span narrows. Never slice past a section the lead
has not completed. This applies equally to a POST-COMPACTION resume
that lands inside a gate: the mandated re-read of `gate-validation.md`
is the `gate-slice.sh` plan narrowed by `gate-checkpoint.sh done`
(Rule 21), not the whole file.

**(c) Offload high-volume observational Bash (context-mode).** Large
*read-only* command output (test-suite runs, gate-validation script output,
`git log`/`diff`/`status` inspection, log scans) MUST be run via
`ctx_batch` / `ctx_execute` so its bytes stay out of the resident
prefix. Two hard limits: (1) state-mutating commands (`git`
commit/branch/merge/worktree, `gh`, `chmod`, file writes) MUST run via
native Bash — a context-mode subprocess discards filesystem changes, so
routing a mutation through ctx silently no-ops it; when in doubt whether a
command mutates, use native Bash. (2) Verbatim-load files (rule/step/role
files, schemas, snapshot, `gate-log.md`, escalations, `audit-anchors.md`,
`sprint-status.yaml`, story files) are never read through any `ctx_*` tool —
consolidation drops directives and breaks load fidelity.
`ai-dlc-protect.sh` blocks the file, path and batch-command forms only, and
is the SET's source of record: `PROTECTED_PATTERNS` there, extended per
project by `extensions/protected-paths.json`. A directory or glob that spans
one of those files is blocked too. Archives and the planning corpus (`prd.md`,
`product-brief.md`, `carry-over-backlog.md`) are deliberately NOT protected —
offload them freely.
