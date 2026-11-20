### Rule 25 -- Artifact-size discipline

This file is the full text of Rule 25 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

Living planning artifacts that grow without bound are the single
largest read cost in the pipeline: a PRD or backlog that accretes every
sprint becomes larger than the context window, so reading it forces
compaction and dominates cache-read. Living artifacts MUST stay
current-state; historical and superseded content MUST move out of the
read path.

**Where an artifact LIVES is a separate rule, and it has one home.** The
path grammar — the directory is the only sprint slot, `<area>/s<N>/`, and
no basename may carry a sprint token — lives in
`artifact-path-grammar.md` alongside this file. READ AND FOLLOW it (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before
writing a pipeline artifact to a path this rulebook does not already
name — **and before handing a session or run name to a `/bmad-*`
sub-skill, because those compose their own output directory from it and
rule 6 governs that name as a path component.** A basename carrying the sprint forces every reader to SEARCH for
the current one, and search means mtime: that is how both pipeline hooks
came to pick the live adversarial series by modification time across 56
sprints in one directory, and how Check 6 verified two closed sprints
against zero story files.

**(a) Current-state live, history archive — move, never delete.** The
live artifact holds what is *currently true*, consolidated. Superseded
requirement versions and prior per-sprint scope narrative are **moved**
(cut-and-paste, verbatim) to the artifact's history/archive file
(`prd.md` -> `prd-history.md`, `product-brief.md` ->
`product-brief-history.md`, `carry-over-backlog.md` ->
`carry-over-backlog-archive.md`, `architecture.md` ->
`architecture-history.md`). The architecture doc is a living artifact under
this rule like any other: per-sprint addenda and superseded ADRs relocate to
`architecture-history.md` rather than accreting inline (the architecture step
rotates on every update). Nothing is ever dropped — the
union of live and history must preserve every prior requirement and
item. Rule 13 locked requirements are by definition current and are never
relocated out of live. History/archive files are write-only — never
read in the hot path — so their growth is free.

**ONE HISTORY FILE ROTATES, AND IT IS NAMED HERE BECAUSE THE SENTENCE
ABOVE IS OTHERWISE FALSE FOR IT.** `pipeline-snapshot-history.md` is fed
by the trim remedy at *every gate* — route.md Step 0a and route-fresh-start.md Step 1a,
`_gate-procedures.md`, Check 14 — not by a sprint close, so it accretes
on a cadence no rotation step bounded. Measured on the reference
consumer: 87 KB to 617 KB across four weeks and 29 commits, every one of
them `del=0`. Append-only held perfectly; nothing was watching the
size. "Never whole-read" was prose with no enforcer, and the only
mechanism that touches it points the other way — `*-history.md` sits in
`ai-dlc-protect.sh`'s `EXCLUDED_PATTERNS`, so a whole Read of that file
is EXPLICITLY ALLOWED and costs ~154k tokens. Rotation is what makes an
accidental read survivable. Entries older than the live window move to
`_bmad-output/pipeline-history/pipeline-snapshot-archive.md` — ONE file,
appended forever, itself unbounded and genuinely free — by
`scripts/ai-dlc/rotate-snapshot-archive.sh`, which is the only writer.
**The archive is load-bearing, not filing.** Check 35's corpus is every
tracked `*.md` in the working tree; on the reference consumer 62 of 89
candidate lines live only in this history, so a rotation whose
destination is ignored or unstaged takes destroyed lines from 17 to 79
against a floor of 40. The rotator refuses an ignored destination and
stages the archive itself for that reason. **No other history or archive
file rotates** — the banners in `ai-dlc-pause.sh` and
`ai-dlc-answer-capture.sh` reading "Rotation: none, ever." still hold
verbatim.

**THE MOVED BLOCK IS HEADED, AND THE HEADING IS A `## ` LINE.** Every
block a move lands in a history/archive file opens with

```
## [MOVED <ISO-8601 timestamp> from <source basename> — <trigger>]
```

**The `## ` is load-bearing.** `rotate-snapshot-archive.sh` cuts at the
Nth-from-last `^## ` line and never interprets a heading, so a block
headed any other way is not a cut point, and moves only when the entry
containing it does.

**(b) Slice-read large sectioned artifacts.** Read the section(s)
relevant to the current scope, not the whole file (Rule 23(b)).
Exception: cross-cutting evaluations that must weigh every item against
the whole requirement set (e.g. `carry-over-evaluation`) read the live
file whole and rely on (a) keeping it bounded — slicing there would
risk missing a cross-reference and mis-deciding.

**That exception is conditional.** A whole-read is licensed ONLY while the
artifact is within its (d) budget. Over budget, the exemption is void —
consolidate first (`artifact-consolidation.md`), then read whole.

**(c) Rotate append-only logs.** `gate-log.md`, the hook-written flow log
`pipeline-continuation-log.md`, the hook-written
`context-mode-protection-log.md`, and similar logs rotate
at epoch/sprint boundaries into
`implementation-artifacts/s<N>/<basename>-archive.md` — the destination
`artifact-path-grammar.md` owns, sprint-keyed by DIRECTORY, never dated in the
basename, because the preamble above makes the directory the only sprint slot.
The live log holds only the current epoch. Verifying an appended entry reads the
**tail**, not the whole file — except Check 15's budget-evidence arm, which
selects by heading timestamp (`validate-artifact-budget.sh --check-evidence`).

**ROTATION HAS TWO SITES AND NAMING ONLY THE FIRST IS WHAT DEADLOCKS A CONSUMER.**
The scheduled rotation is `retro.md` §4b (`pipeline-continuation-log.md`,
`context-mode-protection-log.md`) and §7a-post (`gate-log.md`,
`compaction-log.md`). The UNSCHEDULED one is route-fresh-start.md Step 1a's `rotate` remedy,
which fires when a log has grown past budget with no close in reach — the log
re-fills from hook activity after a retro closes, and a session that reads §4b as
the only sanctioned rotation concludes it cannot start the sprint and cannot
close it either. Step 1a's remedy is a rotation site; see it for which `s<N>`
an inter-sprint epoch takes and why the ordinal is mandatory there.

A log bound by no rotation
step is unbounded: every log is named here explicitly, and (d) is what
catches one this list omits. The escalation log `pending.md` is
bounded the same way: terminal (RESOLVED / OVERRIDDEN) entries move to
`pending-archive.md` at retro close so the gate-read stays scoped to open
escalations — mechanism in `escalations.md` "Terminal-entry archival".

**(d) Size budgets — blocking at sprint start, warn-only at retro.** The
canonical per-artifact budgets and their remedies live in ONE place,
`scripts/ai-dlc/validate-artifact-budget.sh`, which every caller runs rather than
restating (a threshold copied into prose is a threshold that drifts from the one
that executes).

Where it runs decides what it does:

- **Sprint start** (`route-fresh-start.md` Step 1a) — **HARD_BLOCK**.
- **Gate Check 14** — **FAILS the gate** for `pipeline-snapshot.md` alone. The
  snapshot is the one artifact that grows *within* a sprint, and it is re-read at
  every gate, every resume, and every compaction.
- **Retro** (`retro.md` Close-Out Sweep) — **warn-only**. Retro reports, it does
  not gate.

**Warn at 100%, block at 100% + grace** (`AI_DLC_BUDGET_GRACE_PCT`, default 10).
An over-budget artifact is always *reported*; only a breach past the band *blocks*.

Consolidation itself stays operator-invoked (`artifact-consolidation.md`): it is a
fidelity-critical rewrite and must be supervised.
