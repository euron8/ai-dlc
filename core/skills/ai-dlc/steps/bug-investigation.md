---
name: bug-investigation
description: Bug path — investigate root cause, create fix story, route to implementation
nextStepFile: conditional (see Step 6)
---
<!-- STEP_LOADED_TOKEN: bug-investigation -->

# Bug Investigation (Phase 1D-bug)

**Purpose:** Investigate a bug, determine root cause, create a targeted
fix story, then route to implementation.

## EXECUTION SEQUENCE

### 0. Exploration dispatch (Rule 24)

If `planning_offload: on` (default), do NOT run sections 1–2 inline.
Spawn an `analyst` subagent (Agent tool, bound to the analyst role file `.claude/team-roles/analyst.md` per SKILL.md Rule 19 — both bindings: `model` and the standing role-contract Read line) scoped to
sections 1–2 — it loads context, investigates, reproduces, and traces
root cause, then writes its findings (root cause, repro, affected
files/call-sites, and any relief the operator can apply without a
deploy — or `operator relief: none found`) to
`_bmad-output/planning-artifacts/bug-analysis.md`,
returning only `{artifact_path, summary, gaps}`. Then resume at section
2b (Operator Relief) using the analysis — NOT at section 3. The lead authors the fix
story, validates, and owns it. If `planning_offload: off`, run all
sections inline. Per SKILL.md Rule 24.

### 1. Context Loading

Read planning artifacts:
- `_bmad-output/planning-artifacts/prd.md`
- `docs/architecture.md` or `_bmad-output/planning-artifacts/architecture.md`
- `_bmad-output/planning-artifacts/s<N>/test-strategy.md` (if exists), where
  `<N>` is `sprint_id` from the pipeline snapshot's Sprint Context. A bug route
  may run in a sprint that authored no test strategy of its own; when that slot
  is empty, read the most recent `s*/test-strategy.md` and **say which sprint it
  came from** in the analysis. Do not read
  `_bmad-output/planning-artifacts/test-strategy.md` — any file at that path is
  one sprint's strategy stranded at the durable root.

### 2. Investigation

Read the relevant source code, tests, and configuration. Trace the bug
to its root cause. Document:
- **Root cause:** what is wrong and where
- **Root-cause input, not just location:** trace whether the inputs FEEDING
  the root cause were themselves computed correctly. "A distinct root cause"
  names WHERE the defect is, not whether the values it acts on are right — a
  fix that corrects the site while leaving a wrong input upstream still ships
  the defect (e.g. a safeguard that fires correctly on a mis-computed input).
- **Impact scope:** what else is affected
- **Classification:** design flaw vs. implementation error

If the bug reveals a **DESIGN FLAW** that requires architecture changes:
- Document the finding
- The pipeline will automatically run through the full planning cycle
  (discovery → architecture → stories) to plan the fix properly
- Route to `discovery.md` instead of creating a fix story here

If the bug is an **IMPLEMENTATION ERROR**: proceed with fix planning.

**Falsification ladder.** For each architectural layer that the bug
could plausibly originate from, the investigation MUST document why
that layer IS or IS NOT the root cause, with evidence (query result,
code trace, or test output). "Likely cause at layer X" without
evidence ruling out other layers is insufficient. Violation: gate
fails on incomplete falsification.

**Revert-control completeness.** "Root cause identified" is a
classification, not a proof the fix is complete. The null hypothesis the
fix must rule out is: what degenerate or incomplete fix would still earn
the root-cause label while leaving part of the original defect live?
Prove it with a control — revert the fix, confirm the ORIGINAL symptom
returns UNCHANGED IN SHAPE, then re-apply. The revert result is required
evidence in the fix story (`reverted at <sha>, original symptom <X>
reproduced in shape, re-applied`); its absence fails the gate exactly as
an incomplete falsification ladder does. Ties to the falsification ladder
above: that proves the cause is correctly LOCATED, this proves the fix is
COMPLETE.

### 2b. Operator Relief

**When the investigation found relief the operator can apply WITHOUT a
deploy — a config value, a restart, an existing endpoint or admin action, a
feature flag — put it to the operator with `AskUserQuestion` BEFORE section 3**,
recommended option first: **apply now (recommended)** / **wait for the fix**.
State the relief's limit in the question; a stopgap that only buys time is
still asked. Ask it now: if another question is due in the same turn, send
both as separate questions in one `AskUserQuestion` call, and never hold this
one back for another. Ask once per relief, and set NO pause flag (SKILL.md
Rule 3(a)).

If none exists, record `operator relief: none found` in the analysis and
continue.

**The lead cannot apply the relief, so nothing substitutes for asking.** It is
never written into a story as a substitute for the question, and never recorded
in the analysis as an autonomous Rule 12 Tier 2 decision. The question is not
held back behind any review a project adds between section 2 and section 3.

### 3. Create Fix Story

Create a bug-fix story in `_bmad-output/planning-artifacts/s<N>/stories/`:
- Source Requirements section quoting the bug report verbatim
- Root cause description
- Fix approach
- Acceptance criteria (what "fixed" looks like)
- Regression scope (existing tests, new tests needed)
- `capabilities:` naming the capability the fix changes, when the fix is folded
  into a sprint whose `pipeline_variant` runs an architecture step (section 4
  dispatches that capability's architect)

**If the user specified a particular fix approach or scope, preserve it
(Rule 13). Do not substitute a different approach.**

### 4. Validation

Dispatch ONE `adversary` (Agent tool, bound to `.claude/team-roles/adversary.md`
per SKILL.md Rule 19) to run `/bmad-review-adversarial-general` on the fix story.
**ONE-SHOT — the bmad skill is correct here and stays** (no loop, no verdict, no
counted exit condition; the skill's ≥10 floor buys a cynical sweep and costs
nothing). The native `adversary` review is for CONVERGENCE cycles only.
- Is it the right fix or just a patch?
- Will it introduce regressions?
- Is test coverage sufficient?
- **Source fidelity pass:** Does the story address the specific issue
  described? Does the fix approach match what was requested?
- **Architecture fidelity:** does the story's `capabilities:` name the
  capability that the files it changes implement?

It writes findings to `_bmad-output/planning-artifacts/s<N>/bug-fix-oneshot-<slug>.md`,
where `<slug>` is the fix story's own slug, so each bug in a sprint has its own
one-shot. The file carries a `SKILL_INVOCATION_PROVENANCE v1` block with
`skill: bmad-review-adversarial-general`, `mode: subagent`, `artifact:` naming
the fix story, and the three `findings_*` counts — and **no `verdict`**, which a
one-shot never stamps. That `artifact:` line is what routes the story to Check
17's bug-fix arm. The path must not carry an `-adversarial-p<M>` suffix: Check 24
globs that prefix and a verdict-less pass swept into a series fails rung A.

Apply all improvements through the **Adversarial repair dispatch** sub-routine
(`_gate-procedures.md`): ONE `remediator` takes the whole finding set, applies the
edits and appends the changelog to the story. The lead owns the disposition, not
the edit.

**A one-shot finding that yields relief the operator can apply** — an existing
endpoint or admin action that turns the fix into an operator action — goes to the
operator through section 2b's question WHEN IT IS FOUND, not after the disposition.

**Fold architecture dispatch.** When the fix story is FOLDED into a sprint (by
`stories-test-strategy.md` §3a or `route.md` Step 4) and that sprint's
`pipeline_variant` runs an architecture step in `route.md`'s variant table, the
sprint's architecture assessment predates the fold and says nothing about it.
After the remediation above lands, dispatch ONE `architect` (Agent tool, bound to
`.claude/team-roles/architect.md` per SKILL.md Rule 19) over the fix story and
the files it changes. The architect:
1. Runs `/bmad-review-adversarial-general` on the fix story, scoped to
   architecture fidelity: does the change stay inside the sprint's existing ADs
   and component boundaries, and does the story's `capabilities:` name the
   capability the changed files implement.
2. Dispositions that capability from what the review found: an AD extension
   binding it, or a `- **No-AD:** CAP-<n> — REASON: …` line.
3. Writes the residue
   `_bmad-output/planning-artifacts/s<N>/fold-architecture-<slug>.md` (the same
   `<slug>` as the one-shot), carrying its review's findings and one
   `SKILL_INVOCATION_PROVENANCE v1` block with these fields:
   - `skill: bmad-review-adversarial-general`, the skill step 1 ran;
   - `invoked_at:` when it ran, ISO 8601 UTC;
   - `tool_use_id:` the id of the Agent dispatch that spawned the architect, never
     the Skill call's id, because the gate joins it to that dispatch's spawn-ledger
     row;
   - `mode: subagent`;
   - `lead_role: bug-investigation.md`;
   - `artifact:` the fix story's path, exactly as the one-shot's `artifact:` spells it;
   - `findings_critical:`, `findings_major:`, `findings_minor:`, the review's counts;
   - no `verdict`, because this is a one-shot.

Check 17's fold architecture gate reads the residue. The lead does not author the
disposition for a folded capability. The gate proves that an architect was
dispatched in this sprint after the one-shot and that no other fold residue
cites the same dispatch. It does not prove the disposition text came from that
architect, and an unrelated architect dispatch later in the sprint also
satisfies it.

**Then stamp the story — MECHANICALLY, never by hand.** Check 17's bug-fix
story-readiness gate requires a `SKILL_INVOCATION_PROVENANCE` block on the story
itself, and nothing else writes one. Run:

`scripts/ai-dlc/stamp-story-provenance.sh --terminal
_bmad-output/planning-artifacts/s<N>/bug-fix-oneshot-<slug>.md --profile
bug-story-provenance <story-file>`

`--profile bug-story-provenance` is load-bearing: the default profile pins the
convergence skill and demands `verdict: EXIT_CONDITION_MET`, so it refuses every
bug story by construction. You author nothing; the gate's `--check` re-derives
the same block and fails on any drift.

**Direct fold: run the gate arms now, before any dev dispatch.** When this
section runs for `route.md` Step 4's direct fold, sections 5 and 6 are skipped,
so no gate follows before the dev writes into the story. Right after the stamp
above, run Check 17's "Bug-fix story readiness gate (bug-investigation)" bullet
on the story, both halves including the CROSS-CHECK, and Check 17's "Fold
architecture gate (bug-investigation)" bullet, each exactly as that bullet
spells its commands. Type none of them here and run nothing else on the
residue. Every command must exit 0 before a dev is dispatched on the story.
This is the last point at which the story's bytes are the ones the stamp
hashed; the later implementation gates run only Check 17's "Implementation
gate, declared folded bug-fix stories (implementation)" bullet, which omits
the cross-check.

### 5. Sprint Setup

Run `/bmad-sprint-planning` to set up a single-story sprint.

### 6. Gate Validation and Proceed

Run gate validation [implementation] (`gate-validation.md`).

**A FAIL on a check the next step does not consume routes now and repairs
in parallel.** On any FAIL, before routing:

1. For each FAILing check, name the artifacts its remediation writes.
2. Dispatch the repair for every FAILing check through the **Adversarial
   repair dispatch** sub-routine (`_gate-procedures.md`), backgrounded.
3. Route below in the SAME message as that dispatch when no FAILing
   check's remediation writes an artifact the next step reads. A check
   whose remediation writes only the gate log, the snapshot, the spawn
   ledger, or a role contract writes nothing a story dev reads. A FAIL on
   story content or on acceptance criteria writes what the dev reads, and
   holds the routing until it PASSes.
4. Re-run gate validation when the repair lands. No story lands and the
   sprint does not complete until the entering gate PASSes.

Then:

If design flaw detected:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/discovery.md`

If implementation error:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/implementation.md`
