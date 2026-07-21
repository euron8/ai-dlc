---
name: retro
description: Sprint retrospective — agent runs autonomously, human comments before close
nextStepFile: STOP
---
<!-- STEP_LOADED_TOKEN: retro -->

# Retrospective (Phase 5)

**Purpose:** Review the sprint, extract lessons, apply process
improvements. The agent runs the retro autonomously. The human gets
a chance to comment or ask questions before it closes.

## EXECUTION SEQUENCE

### 1. Context Loading

Create the retro branch using the canonical name that
`scripts/validate-mandatory-rules.sh` expects:

```bash
git checkout -b ai-dlc/retro/sprint-<N>
```

The branch name MUST contain `sprint-<N>` (literal word "sprint"
followed by the sprint number). Abbreviated forms (`s<N>`,
`retro-<N>`) cause validation failures because the script's
branch-detection regex requires the `sprint-<N>` substring.

**Context digest (Dispatch A — Rule 24).** Branch creation above stays
inline — it is a git mutation (Rule 28(a) / Rule 23(c): mutations run
native, never through a subagent that discards the FS). Dispatch A is
issued only AFTER the branch exists.

If `planning_offload: on` (default), do NOT read the sprint artifacts
inline. Spawn an `analyst` subagent (Agent tool, bound to the analyst role file `.claude/team-roles/analyst.md` per SKILL.md Rule 19 — both bindings: `model` and the standing role-contract Read line)
scoped to the sprint-artifact read — it reads:
- Sprint stories in `_bmad-output/planning-artifacts/stories/`
- Code reviews in `docs/reviews/`
- Gate log at `_bmad-output/implementation-artifacts/gate-log.md`
- Escalation log at `docs/escalations/pending.md`
- Sprint-status.yaml
- Context-mode protection log at `_bmad-output/context-mode-protection-log.md` (if it exists)

and writes a structured digest to
`_bmad-output/retro-artifacts/sprint-<N>-context.md` — planned-vs-delivered
table, rework-cycle count, `DECIDED_AUTONOMOUSLY` list, `hard_block_count`
+ `hard_block_class[]` tally, per-escalation state, gate-log outcomes —
returning only `{artifact_path, summary, gaps}`. The lead consumes the
digest in Step 3 (reads it from disk only when a decision needs it, Rule
23(a)); an absent artifact at the returned path is non-delivery → the
lead re-dispatches. If `planning_offload: off`, read the artifacts
inline. Per SKILL.md Rule 24.

Run auto-handoff evaluation at `Seam E` with the label
`retro Step 1 pre-flight` (see `_gate-procedures.md` \"Auto-handoff
evaluation\"). If evaluation returns FIRE, the session ends;
otherwise continue to Step 2.

### 2. Party Mode Retro

Execute all sub-skills back-to-back without pausing for human input
between them.

**Invoke `/bmad-party-mode` via the Skill tool.** The Skill invocation
IS the satisfier for this step — role-playing PM/Architect/Dev/SM/
TEA/QA perspectives inline in the retro doc without invoking the
Skill is a Rule 3 violation per SKILL.md, regardless of how
well-formed the output appears. This is non-negotiable.
Each agent MUST be spawned as a real subagent for independent perspective. Solo mode (roleplaying agents inline) is forbidden.
**Pass the Rule 20 role-manifest preamble** so each persona Reads and
debates from its `.claude/team-roles/<role>.md` (PM→`pm.md`,
Architect→`architect.md`, Dev→`dev.md`, SM→`sm.md`, TEA→`tea.md`,
QA→`qa.md`).

Bring all agent perspectives (PM, Architect, Dev, SM, TEA, QA) into
the discussion:
- Walk through every story's journey from plan to merge
- What worked well in the pipeline
- What caused friction or rework
- Where requirements drifted (check LOCKED_REQUIREMENTS fidelity)
- Where evidence requirements caught issues vs where they were missed
- Process improvements to propose

**Mandatory artifacts from this step (all three):**

1. **Skill invocation evidence.** The `/bmad-party-mode` Skill tool
   call must occur in the lead's own conversation. A `SKILL_INVOCATION_PROVENANCE v1`
   block (schema in SKILL.md Rule 3) is written to the retro doc
   citing the invocation's `tool_use_id`, `invoked_at` timestamp,
   `mode` (solo or subagent), and `transcript_path`.

2. **Transcript file commit.** The party-mode transcript (all agent
   responses in full, not summarized) is committed to
   `_bmad-output/party-mode-transcripts/sprint-<N>-retro.md`. This
   file is the byte-for-byte authoritative record; the retro doc's
   "Agent findings" section in Step 3 summarizes but does not
   replace it.

3. **Provenance block cites transcript@sha.** The provenance block's
   `transcript_path` field uses the `path@<sha>` format where
   `<sha>` is the **commit** SHA of the commit that added the transcript
   — NOT the blob SHA. `scripts/validate-retro-evidence.sh` resolves the
   citation with `git cat-file -p <sha>:<path>`, and that syntax takes a
   tree-ish: handed a blob it exits `fatal: path '<path>' exists on disk,
   but not in '<sha>'`. It then enforces byte-match between the cited
   SHA's content and the file on HEAD.

**Author the transcript to pass on the first commit — do not backfill.**
`validate-retro-evidence.sh` enforces a shape floor and
`validate-provenance-block.sh` a provenance format, both at the Step-5c gate.
Discovering those there and patching the transcript afterward re-invalidates
the cited commit SHA (forcing a re-cite) and often triggers a provenance
reformat — a multi-commit loop repeated every sprint. Prevent it by satisfying
both at authoring time and committing in this order:

1. **Shape the transcript to the floor before committing it.** It MUST clear
   `validate-retro-evidence.sh`'s floor — that script is the single source of
   the thresholds (do NOT restate the numbers here, where they can drift):
   at least its required count of distinct persona markers, at least its
   required count of distinct canonical `Phase N` labels (from its
   `PHASE_LABELS` allow-list), and its minimum character count. Committing the
   full agent responses verbatim (not summaries) clears all three.
2. **Commit the transcript as its own commit first**, then read back that
   COMMIT's SHA: `git rev-parse HEAD`. Not `git rev-parse HEAD:<path>` — that
   returns the BLOB sha, which is exactly the citation the validator rejects.
   Committing the transcript alone
   is what makes `HEAD` name it unambiguously.
3. **Write the `SKILL_INVOCATION_PROVENANCE v1` block once**, citing that SHA. Copy the
   envelope below exactly — the delimiters are what the parser reads, and a block in a ```
   fence is scored as no block at all. Get it right the first time; a reformat pass is the
   same wasted loop as a re-cite.

<!-- BEGIN GENERATED: provenance-block/retro-party-mode — source: schemas/provenance-block.json; do not edit by hand -->
```
<!-- SKILL_INVOCATION_PROVENANCE v1
skill: bmad-party-mode                      # the evaluation that ACTUALLY RAN. Naming one you did not invoke is a forged block.
invoked_at: <ISO 8601 UTC, to the second>   # Check 24 orders the pass series on this. Ambiguity here reorders the cycle.
tool_use_id: <toolu_... — from the Skill tool response, or the Agent dispatch that spawned you> # the id of the Skill/Agent call that ran this evaluation. CHECKED FOR SHAPE ONLY — nothing verifies it against a transcript, so it is not proof the evaluation ran.
mode: subagent                              # never solo.
lead_role: <the step file that invoked or dispatched the evaluation> # which step owns this pass.
transcript_path: <_bmad-output/party-mode-transcripts/sprint-<N>-retro.md@<sha>> # required for retro party-mode; byte-matched by validate-retro-evidence.sh.
findings_critical: <int>                    # the residue the verdict is adjudicated against. Required of EVERY known evaluation, not only verdict-bearing ones — see rules.counts_always.
findings_major: <int>                       # omit it and the stall rung goes silent for the ENTIRE series.
findings_minor: <int>                       # the nitpick bucket. Does not block the exit condition.
SKILL_INVOCATION_PROVENANCE_END -->
```
<!-- END GENERATED: provenance-block -->

4. **Never edit the transcript after citing its SHA.** Any byte change makes the
   cited SHA stale and forces steps 2–3 again. If the transcript is wrong, fix
   it before step 2, not after step 3.

Local enforcement runs in Step 5c (pre-commit validation gate) and is
authoritative. CI enforcement is conditional: a consumer that ships
`.github/workflows/validate-retro-compliance.yml` re-runs the same scripts
on the retro PR; a script-based consumer with no `.github/workflows/`
directory runs them locally only.

### 3. Write Retro Document

**Doc split (Dispatch A, continued — Rule 24).** If `planning_offload:
on`, dispatch an `analyst` subagent (Agent tool, bound to the analyst role file `.claude/team-roles/analyst.md` per SKILL.md Rule 19 — both bindings: `model` and the standing role-contract Read line)
to draft the **descriptive/analytical** sections only — the sprint
summary, `hard_block_count` + `hard_block_class[]`, and the **Agent-findings
summary** — from (a) the Step-1 context digest and (b) the committed
party-mode transcript. It writes the draft to
`_bmad-output/retro-artifacts/sprint-<N>-retro-draft.md`, returning only
`{artifact_path, summary, gaps}`. Two hard constraints on that draft:
- The Agent-findings summary MUST cite the existing `transcript_path:
  path@<sha>` verbatim and summarize that already-byte-cited transcript.
  It NEVER re-derives party-mode findings from scratch (that path is
  solo-mode-by-proxy, a Rule 20 violation).
- The analyst NEVER writes a `SKILL_INVOCATION_PROVENANCE` block (Rule
  24: the analyst produces inputs, not validated outputs; the provenance
  block stays the lead's, written in Step 2 / verified in Step 5c).

The **prescriptive** sections stay lead-authored inline — they are the
retro's decision content (pipeline self-governance), as non-delegable as
gate decisions: "specific, actionable improvements," "which improvements
should update CLAUDE.md / team roles / pipeline steps," and the Step-4
5-layer enforcement decisions. The lead assembles the analyst draft and
its own prescriptive sections into the final retro doc. If
`planning_offload: off`, write the whole doc inline. Per SKILL.md Rule 24.

Write the retro to `docs/retro/sprint-N.md` with:
- Sprint summary (planned vs delivered, rework cycles, autonomous decisions)
- `hard_block_count` (integer): total HARD_BLOCKs encountered this sprint
- `hard_block_class[]`: list of HARD_BLOCK classifications (e.g., requirement-divergence, scope-conflict, infra-outage)
- Agent findings (from party mode)
  with finding-class per pass (see templates/retro-finding-class-tracking.md)
- Specific, actionable improvements
- Which improvements should update CLAUDE.md, team roles, or pipeline steps

Retro findings asserting infrastructure topology MUST cite the
IaC source file and line (Terraform, CDK, CloudFormation, Docker
Compose, or equivalent). Agent consensus is not evidence of
topology shape. Any analyst-drafted finding asserting topology MUST
carry the IaC `file:line` citation in the draft; the lead validates the
citation before the finding lands. The analyst surfaces the citation —
it never substitutes agent consensus for it.

### 4. Apply Process Improvements

If the retro identifies changes needed to CLAUDE.md, team role files,
pipeline step files, or coding conventions:

**For new hard requirements (non-deferrable rules, hard gates):**
Adding rule text to one file is not sufficient. Every new hard
requirement must be enforced at ALL applicable layers:
1. **Rule definition** — coding-conventions.md or CLAUDE.md (the rule itself)
2. **Gate validation** — gate-validation.md (structural check that fails
   the gate if the rule is violated)
3. **Dev checklist** — dev.md pre-submission checklist (evidence requirement)
4. **Code review severity** — code-reviewer.md mandatory severity
   classification (missing = Critical)
5. **QA validation** — qa.md validation checklist (reject if missing)

If a retro action item says "hard gate" or "non-deferrable," it MUST
be applied at all 5 layers. Applying it to only 1-2 layers makes it
advisory, not structural.

**For advisory improvements (best practices, conventions):**
- Apply the change to the relevant file(s)

**For all improvements:**
- Document what was changed and why in the retro doc
- List which files were modified and which enforcement layers were added

**Rule text authoring:**
Follow SKILL.md Rule 18. Rules must be imperative or MUST/MUST NOT/SHALL,
state the enforcement consequence inline, and contain no origin narrative.
The WHY of each improvement goes in the commit message below, not in the
rule file.

#### Rule file audit (every retro)

**Ordering is load-bearing.** This scan MUST see post-improvement file
state, so it is issued only after the "apply process improvements" edits
above land (§2 blocker 1) and before the Step-5c audit commit.

If `planning_offload: on`, dispatch a **single** `analyst` subagent (Agent tool, bound to the analyst role file `.claude/team-roles/analyst.md` per SKILL.md Rule 19 — both bindings: `model` and the standing role-contract Read line) for **all** of Step 4's post-improvement scans — this rule-file audit **and** the path-filter dormancy + relocation-pointer-invariant-1 scans below. All fire at the identical post-improvement point; the "Scan dispatch" below extends this one spawn rather than adding a second (a second round-trip at the same causal point buys nothing). This dispatch produces the **candidate list** — scanning the files and violation
classes below and, for each suspected violation, recording `file:line`,
the violation class (narrative-drift / weakness / complexity-accretion),
the bare-rule-survives-without-narrative judgment as a **recommendation**,
and for accretion findings the catch/false-positive tally. Written to
`_bmad-output/retro-artifacts/sprint-<N>-rule-audit-candidates.md`,
returning only `{artifact_path, summary, gaps}`. Detection is the
delegable read. The lead **dispositions each candidate and authors every
rewrite inline** — rule rewriting is a governance judgment expressed as
text, tightly coupled to disposition; routing the decided text-insertion
to a dev is pure overhead (Rule 26: no dispatch hop for a decision the
lead already made). If `planning_offload: off`, scan inline. Per SKILL.md
Rule 24.

**Structural invariant (retro audits itself).** The scan of
`.claude/skills/ai-dlc/steps/*.md` MUST assert that every read-heavy
section of `retro.md` (Steps 1, 3, 4, 4a, 7b) carries its analyst
dispatch when `planning_offload: on` (Step 4's rule-file audit and its
dormancy/pointer scans share one post-improvement dispatch — that is one
carried dispatch, not a missing one); a read-heavy retro section that
reads inline instead is a Rule 28 lead-conduct finding.

The analyst scans the following files for violations of SKILL.md Rule 18:

- `CLAUDE.md`
- `docs/coding-conventions.md`
- `.claude/skills/ai-dlc/steps/*.md`
- `.claude/team-roles/*.md`
- `.claude/skills/ai-dlc/extensions/**/*.md`
- `.claude/skills/ai-dlc/overrides/**/*.md`

The last two are not an afterthought. Rule 27 forbids a consumer to hand-edit any of the
first four, so a scope naming only those scans exactly the text the consumer cannot author
and stays silent on all the text it does. The blind spot follows from the layering itself,
which means every consumer that adopts Rule 27 has it, and the audit's CLEAN verdict is
indistinguishable from its never having run against the relevant corpus. Measured on the
reference consumer: six blocks of narrative drift added across two `extensions/` files in one
sprint, with the audit reporting `Class 1: CLEAN (of 39 files scanned)` throughout.

**The `**` is load-bearing — do NOT narrow it to `*`.** `extensions/` is conventionally
organised into subdirectories (`checks/`, `roles/`, `steps-domain/`), so a single-level glob
matches the README and nothing else. Measured on the reference consumer: `extensions/*.md`
resolves to **1** file, `extensions/**/*.md` to **32** — and the drift that justified adding
these two lines sits in `extensions/steps-domain/`, outside the narrow form. A scope that
misses the corpus reports CLEAN exactly as loudly as one that scanned it.

Three classes of violation to detect:

**1. Narrative drift.** Rule text contains sprint/story references,
incident descriptions, "because we" justification, parenthetical origin
notes, embedded dates, or quoted retro findings.

**2. Rule weakness.** Rule text uses "should", "try to", "consider",
"prefer", "in most cases", or similar soft language where a mandate is
intended. Missing enforcement consequence where one would apply.

**3. Complexity accretion.** A gate, check, hook, guard, or rule
added in a prior sprint that lacks the Rule 26(c) contract (concrete
failure caught, false-positive cost, removal condition), or whose
false positives since introduction exceed its true catches. For each
such finding, record the catch/false-positive tally and propose
removal or narrowing as a process improvement in this retro —
machinery is removed through the same Step 4 mechanism that added it.

Per finding, judge case by case:
- Is the text part of a rule statement (prescriptive/directive), or
  prose explaining how something works (descriptive)? Descriptive prose
  is exempt from both classes.
- For narrative drift: does the bare rule still make sense when the
  narrative is removed?
  - **Yes** → strip the narrative; the WHY goes to the audit commit message.
  - **No** → the rule is leaning on the story. Rewrite it hard (see
    Rule 18 style), or mark for removal and raise during Step 5 human
    commentary.
- For rule weakness: rewrite the rule using imperative or MUST/MUST NOT/SHALL.
  If the soft language was intentional (genuine advisory preference),
  the rule does not belong in rule files — move it to the retro doc
  as a lesson or remove it.

Record audit results in the retro doc under a `## Rule File Audit`
section: files scanned, narrative drifts found (list each), rule
weaknesses found (list each), complexity accretions found (list each
with catch/false-positive tally), rules rewritten, rules marked for
removal.

If the audit produced file changes, do NOT commit them yet — Step 5c
handles the audit commit as a separate commit before the main retro
commit in Step 6.

If zero violations found, note "Audit: clean" in the retro doc.

**Scan dispatch (Dispatch A, continued — Rule 24).** The path-filter
dormancy scan and relocation-pointer invariant 1 below are read-heavy
multi-file / multi-job scans. They are covered by the **same single
post-improvement analyst dispatch** already issued for the rule-file audit
above — extend that spawn's scope to run both; do NOT spawn a second analyst
(both scans fire at the identical post-improvement point). When
`planning_offload: on`, that analyst returns their tables to
`_bmad-output/retro-artifacts/sprint-<N>-scan-tables.md` (returning only
`{artifact_path, summary, gaps}`): the dormancy table (job, sprint-window,
last non-SKIPPED SHA, `gh run list` evidence) and the pointer table
(pointer, target, exists Y/N, anchor-resolves Y/N). `gh run list` is a
state-read, safe for a subagent. The lead owns the remediation choice and
every HARD_BLOCK verdict below; the analyst gathers evidence, it never
dispositions. **Invariants 2 and 3 are NOT dispatched** — they are compact
`node -e` one-liners; run them via `ctx_execute` (Rule 23(c)) so their
output stays out of the resident prefix and the lead reads only the
IN/OUT and MISSING/ORPHAN verdict lines. If `planning_offload: off`, run
the scans inline. Per SKILL.md Rule 24.

#### Path-filter dormancy scan (every retro)

If the project has no `.github/workflows/` directory (a script-based
consumer that runs validators via `validate-*.sh` / `ci-local.sh`
directly rather than GitHub Actions), record this scan as **N/A** — an
empty workflow set is the expected state, not a dormancy finding — and
skip to the relocation-pointer scan below. Otherwise:

After the rule-file audit, enumerate CI jobs in `.github/workflows/**`
that use `paths:` or `paths-ignore:` filters. For each such job,
determine the last main-branch SHA on which the job actually ran
(not SKIPPED). If ≥3 sprints have elapsed with zero non-SKIPPED runs
on `main`, the retro MUST either (a) cite an existing `schedule:`
cron trigger on the workflow that exercises the job independent of
path filters, or (b) file a Sprint N+1 task to add a weekly
`schedule:` cron run to that workflow. Reporting-only is not
sufficient — a dormancy finding without a remediation path is
narrative drift. Record results in the retro doc under
`## Rule File Audit` in a `Path-filter dormancy scan` sub-section,
including for each dormant job: evidence
(`gh run list --workflow=<wf> --branch=main --limit 30`), sprint
window, and (a) or (b) remediation.

#### Relocation-pointer + resident-ordering scan (every retro)

Resident-context slimming relocates rule bodies out of `SKILL.md` into
JIT files and leaves a pointer at the seam. Three invariants MUST hold
each retro; all are HARD_BLOCK on failure and MUST be fixed before the
Step 5c audit commit.

**1. Every relocation pointer resolves to a live file.** Scan `SKILL.md`
and `.claude/skills/ai-dlc/steps/*.md` for pointers to **skill-loadable
content** — `READ AND FOLLOW \`<path>\``, and prose locators of the form
"lives in / defined in / canonical … in / schema in / see \`<file>\`[
Check N]" that name a step file (`steps/*.md`), a sibling skill reference
file (`rule-authoring.md`, `escalations.md`,
`steps/handoff.md`), or a team-role file (`.claude/team-roles/*.md`). For each, confirm the named
file exists on disk (and, when a specific anchor like `Check 14` is
cited, that the anchor exists in the target). **Out of scope — do NOT
flag:** runtime artifacts and project files that exist only in an
installed project, not in the skill source (`_bmad-output/**`, `docs/**`,
`CLAUDE.md`, and the living/runtime artifacts `prd.md`,
`product-brief.md`, `carry-over-backlog.md`, `gate-log.md`,
`pipeline-snapshot.md`, `pipeline-snapshot.precompact.md`,
`compaction-log.md`, `audit-anchors.md` and their `*-history` /
`*-archive` variants). A skill-content pointer whose target is missing is
a dangling reference — FAIL the audit and either restore the target or
correct the pointer. Zero dangling skill-content pointers is the pass
condition.

**2. The critical set stays inside the first-5K re-attach window.**
Claude Code re-attaches only the first ~5,000 tokens of `SKILL.md` after
compact. Measure the cut point (chars/4 estimate: the first 20,000 chars)
and assert the `## POST-COMPACT RECOVERY PROTOCOL` heading and Rules 3, 4,
and 11 all begin inside it:

```
node -e "const s=require('fs').readFileSync('.claude/skills/ai-dlc/SKILL.md','utf8');for(const t of ['## POST-COMPACT RECOVERY PROTOCOL','### Rule 3 ','### Rule 4 ','### Rule 11 ']){const i=s.indexOf(t);console.log((i>=0&&i<20000?'IN ':'OUT'),Math.round(i/4),t.trim());}"
```

Any target reported `OUT` means a relocation (or an addition ahead of it)
pushed a critical rule past the re-attach boundary — FAIL and reorder so
the critical set precedes the cut before committing. Rules 21–26,
INITIALIZATION, and `## HANDOFF PROTOCOL -- TRIGGERS AND CONTEXT
THRESHOLDS` are second-tier by the file's own design ("may sit past
the 5K boundary") and are NOT required within 5K. The node check tests the
POST-COMPACT *heading* start; the section's whole *body* must also precede
the cut (a protocol truncated by the event it handles is worthless). That
body invariant is mechanized — run `scripts/validate-reattach-budget.sh`,
which FAILS if the protocol's END offset exceeds the re-attach window; a
non-zero exit is a hard audit failure. Record all three results in the retro
doc under `## Rule File Audit` in a `Relocation-pointer + resident-ordering
scan` sub-section: pointers checked (count + any dangling), the measured
token offset of POST-COMPACT + Rules 3/4/11 with IN/OUT verdicts, and the
`validate-reattach-budget.sh` PASS/FAIL with its slack figure.

**3. Every `GATE_MANIFEST` check ID resolves to a live check anchor, and
every check anchor is claimed by the manifest.** The gate-type
slicing (`gate-validation.md` "Gate-type manifest") loads checks by gate
type; a manifest ID with no matching check, or a check with no manifest
claim, silently mis-slices a gate. Two-way resolve against
`steps/gate-validation.md`:
- **Manifest → anchor.** For every check ID listed in a `GATE_MANIFEST`
  table row — `universal` included, it is a row like any other — confirm a
  matching `<!-- CHECK_LOADED: <id> -->` anchor exists in the file. An ID
  with no anchor is manifest drift (a row names a check that was renamed
  or removed) — FAIL.
- **Anchor → manifest.** For every `<!-- CHECK_LOADED: <id> -->` anchor
  in the file, confirm the ID appears in ≥1 manifest row. An orphan
  anchor (a check no gate type requires) is drift in the other
  direction — FAIL.

The command below DERIVES both sides from the manifest and hard-codes no
check ID.

```
node -e "const s=require('fs').readFileSync('.claude/skills/ai-dlc/steps/gate-validation.md','utf8');const anchors=[...s.matchAll(/^<!-- CHECK_LOADED: (\S+) -->$/gm)].map(m=>m[1]);const m=s.slice(s.indexOf('GATE_MANIFEST v1'),s.indexOf('GATE_MANIFEST_END'));const rows=[...m.matchAll(/^\|[ ]*([a-z][a-z-]*)[ ]*\|([^|]*)\|/gm)];if(!rows.length)throw new Error('GATE_MANIFEST: no rows parsed — the scan would pass by comparing nothing');if(!rows.some(r=>r[1]==='universal'))throw new Error('GATE_MANIFEST: no universal row — the always-loaded set is unreadable and every universal check would report as an orphan');const ids=new Set();for(const r of rows)for(const t of r[2].split(',').map(x=>x.trim()).filter(Boolean))ids.add(t);const missing=[...ids].filter(i=>!anchors.includes(i));const orphan=anchors.filter(a=>!ids.has(a));console.log('rows:',rows.map(r=>r[1]).join(' '));console.log('MISSING (manifest ID, no anchor):',missing.join(' ')||'none');console.log('ORPHAN (anchor, no manifest claim):',orphan.join(' ')||'none');"
```

Both lists MUST be empty. Record the result in the same
`Relocation-pointer + resident-ordering scan` sub-section: manifest IDs
resolved (count + any MISSING/ORPHAN).

## Empirical gate validation

Every gate added via retro MUST be exercised on a green run within the next
PR that naturally touches the gate's enforcement domain. Absence of exercise
within that window fails the next retro. Shipping a gate wired to no workflow
trigger, or wired only to a workflow that does not run on any PR in the
exercise window, is the dormant-gate anti-pattern.

Enforcement (conditional on the consumer shipping CI): where
`.github/workflows/validate-ci-gates.yml` is present, `scripts/validate-ci-gates.sh`
runs on every pull request; a script-based consumer with no `.github/workflows/`
runs it locally. The script scans `docs/retro/**/*.md`
for declared gate names and grep's `.github/workflows/**` for each; any
declared gate with zero workflow matches is flagged as DORMANT and the
workflow exits non-zero, failing the PR check. Retro authors MUST ship the
gate's workflow wiring in the same PR as the retro's gate declaration, or
cite the wiring PR that did.

Declaration convention: when a retro adds a new CI gate, name it using the
canonical form `` CI gate `<gate-name>` `` (the gate name enclosed in
backticks, preceded by the literal phrase "CI gate"). This is the only form
the shallow detector harvests; gate names mentioned in free-form prose are
intentionally out of scope.

### 4a. Close-Out Sweep

Implementation is supposed to close upstream items inline as stories
transition to `done` (see `implementation.md` step 5). This sweep is
the backstop: it catches items that slipped past inline closure and
ensures no sprint ends with stale OPEN/IN_SPRINT state.

**Close-Out gather (Dispatch A, continued — Rule 24).** If
`planning_offload: on`, dispatch an `analyst` subagent (Agent tool, bound to the analyst role file `.claude/team-roles/analyst.md` per SKILL.md Rule 19 — both bindings: `model` and the standing role-contract Read line)
to RUN and MATCH — never to dispose. It writes its tables to
`_bmad-output/retro-artifacts/sprint-<N>-closeout-tables.md`, returning
only `{artifact_path, summary, gaps}`:
- **Deferral reconciliation.** For each deferral / re-affirmed deferral /
  passive monitor, the analyst RUNS the live condition (the cited test,
  query, or observable) and returns the reconciliation table: item,
  TRIGGER `file:line`, EFFORT-BLOCKER + estimate, CONDITION + its LIVE
  result, recommended reclassification. Conditions are run LIVE against
  real source — a table that ASSERTS a condition's state without running
  it is non-delivery (§4 invariant 5). TRIGGER `file:line` citations MUST
  survive the hop for the lead to validate (§4 invariant 4).
- **Sweep match table.** Reads carry-over-backlog, escalations, and
  sprint-status and returns item → satisfying story → recommended status.
- **Artifact-size audit.** Measures the live artifacts and returns
  sizes-vs-thresholds.
- **Layer-entry audit (Rule 27, layered consumers only).** Runs
  `scripts/validate-layer-entries.sh` and returns its errors/warnings. Skip on a
  consumer with no `extensions/`/`overrides/` directories (it exits clean anyway).

The lead **dispositions** every row before the PVC — "the lead is the
detector" is catch-before-PVC, satisfied when the lead decides the
reclassification from the analyst's live evidence, not
lead-hands-on-keyboard. **Locked-requirement deferral disposition is
NEVER delegated** — it is a Rule 13 / Rule 12 Tier-1 HARD_BLOCK
governance decision, lead-only (see below). The **mutations** (mark
`CLOSED`, verbatim archive cut-paste per Rule 25(a), status-yaml drift
correction) encode the lead's just-made decision — keep them inline with
the disposition; dispatch the mechanical archive-moves to `dev` only if a
batch is large. If `planning_offload: off`, run the sweep inline. Per
SKILL.md Rule 24.

**Deferral-freshness reconciliation (run BEFORE the three sweeps,
MANDATORY).** For every carry-over deferral, re-affirmed deferral, or
passive monitor whose blocking or monitored condition is a runnable
test, anchor, query, or observable event, the lead MUST re-verify that
condition LIVE at close-out — run the cited test, query the cited
source, or read the monitored signal. If the condition is now satisfied
(test green where it was held red, event observed, value in-band), the
item is reclassified `CLOSED - delivered in sprint <N>` /
`CLOSED - satisfied` with the verification evidence cited — NOT carried,
NOT re-deferred. A deferral whose target is already delivered is a
vacuous deferral, and the lead is its detector: surfacing it as "defer"
at the production validation checkpoint (PVC), where the operator rather
than the lead discovers it, is a close-out failure. Record each
re-verification (item, condition, result) in the retro `## Close-Out
Sweep` section. Rule 26(c): this catches a vacuous deferral reaching the
operator at the PVC; its false-positive cost is one redundant re-run of
an already-runnable check (a still-unmet condition simply confirms the
carry); it is removed when successive retros record zero
reclassifications. Violation: a stale or already-satisfied deferral
surfaced at the PVC → retro finding.

**Deferral-justification triple (MANDATORY — extends the freshness
reconciliation above to the trigger and effort axes).** The freshness
rule checks only the CONDITION axis (is the blocking condition still
unmet?). That is necessary but insufficient: a deferral can be vacuous
because its premise is false OR because it conceals trivially-doable
work. So every carry-over deferral, re-affirmed deferral, and every
sprint-cut deferral surfaced at close-out MUST fill all three slots, and
any unfillable slot reclassifies the item BEFORE the PVC — close it, or
do it now (the lead is the detector, not the operator):
- **TRIGGER** — the specific in-sprint diff or path that creates the
  need, cited `file:line`. No citable trigger → the item is INVALID;
  delete it, do not carry it.
- **EFFORT-BLOCKER** — what concretely prevents in-sprint delivery, with
  an estimate. If the work is below an OBJECTIVE bright-line — a ≤~10-line
  config edit, or the deletion of a single artifact — it is IN-SCOPE NOW,
  not a deferral. The bright-line MUST be objective, never "lead
  judgment".
- **CONDITION** — the runnable test, query, or observable and its
  current LIVE result (the freshness reconciliation above).
  Already-satisfied → `CLOSED - delivered`.
A deferral surviving all three slots is presented at the PVC with its
triple as evidence — a stress-tested deferral the operator reviews, not
one the operator must detect. Rule 26(c): this catches an untriggered or
trivially-doable deferral before it reaches the operator; its
false-positive cost is filling three short slots per surviving deferral;
it is removed when successive retros record zero unfillable slots.
Violation: any deferral or carry-over surfaced at the PVC without its
triple, or the operator (not the lead) catching a vacuous deferral →
retro finding.

**Locked-requirement deferral needs recorded operator disposition.** The
freshness rule above lets an ordinary deferral whose target was already
delivered close as `CLOSED - delivered` — delivery cleanses it. This does
NOT hold for a Rule 13 LOCKED_REQUIREMENT. Deferring a locked requirement
is a requirement divergence: it requires a HARD_BLOCK with an explicit
operator disposition on record (approved-deferral / do-now / descope),
per Rule 13 + Rule 12 Tier 1. Same-sprint delivery does NOT retroactively
cleanse that need — a locked requirement that was deferred and then
delivered still surfaces at the PVC with its recorded disposition, so the
governance fact that a locked requirement slipped its lock is visible and
signed off, not erased by the eventual delivery. A locked-requirement
deferral reaching close-out with no recorded operator disposition is a
retro finding, whether or not the requirement ultimately shipped.

**Minimum mechanism (Rule 26(c)).** Failure caught: a locked requirement
quietly deferred without operator sign-off, with the deferral later
laundered clean by same-sprint delivery so the lock-slip never reaches
the operator. False-positive cost: one recorded disposition line per
deferred locked requirement. Removal condition: retire once locked
requirements cannot be deferred without a structurally-enforced operator
gate.

**Sweep targets (run all three):**

1. **`_bmad-output/planning-artifacts/carry-over-backlog.md`.** For
   every item still marked `IN SPRINT` or `OPEN`, check whether any
   story in this sprint satisfies it. Match on story `Source:`,
   LOCKED_REQUIREMENTS references, or epic linkage. If satisfied and
   the story is `done`: mark the item `CLOSED - delivered in sprint
   <N> via <story-id>` with `closed_at: <ISO date>`, then **move** the
   closed item out of the live backlog into
   `carry-over-backlog-archive.md` (cut-and-paste, verbatim — Rule
   25(a)). The live backlog holds only OPEN / IN-SPRINT / PARTIAL /
   DEFERRED items. If the story shipped but only partially satisfied
   the item: mark `PARTIAL - sprint <N>` and keep the remainder open in
   the live backlog with a note on what remains. If no story touched
   it: leave as-is (it's legitimate carry-over).

   When a carry-over item is partially satisfied, record status as
   `PARTIAL - sprint <N>` with explicit description of what was
   completed and what remains. Keep the remainder open as a new
   carry-over item.

2. **`docs/escalations/pending.md`.** For every entry without a
   RESOLVED or DECIDED_AUTONOMOUSLY terminal marker, check whether
   the sprint addressed it. If yes: append `RESOLVED - sprint <N> -
   <one-line outcome>`. DEFERRAL_REQUEST entries that the human
   accepted at the production validation checkpoint get `DEFERRED -
   sprint <N>` and are moved to the next sprint's carry-over
   backlog (append to `carry-over-backlog.md` as a new OPEN item
   citing the original escalation). Then **archive terminal entries
   (Rule 25(a)/(c)):** move every RESOLVED and OVERRIDDEN entry
   (cut-and-paste, verbatim) out of `pending.md` into
   `docs/escalations/pending-archive.md`, leaving only OPEN escalations
   in the live log so the next sprint's gate-read stays bounded — see
   `escalations.md` "Terminal-entry archival". Nothing is dropped; the
   union of live + archive preserves every entry.

3. **`_bmad-output/implementation-artifacts/sprint-status.yaml`.**
   Final consistency pass: every story with `Status: done` in its
   file MUST have `status: done` in sprint-status.yaml, and vice
   versa. Gate validation check #5 enforced this per-commit; this
   sweep is the last guard against drift. Any mismatch found here is
   a retro finding — record it and fix.

   Then **close the envelope mechanically** — do NOT hand-edit `status:`:

       scripts/sprint-status.sh close \
         --evidence "<what proves the sprint closed: PR/merge, deploy, smoke>" \
         --retro-doc docs/retro/sprint-<N>.md

   This flips `status: done` and writes the `sprint_<N>_housekeeping:` block
   (`envelope_status: done` + non-empty `closure_evidence`) that Step 5c's
   `validate-mandatory-rules.sh` Check 3 reads — the ONLY writer of that block
   (`schemas/sprint-status.json`), write-verified and idempotent. The next
   sprint's `roll` (route.md Step 6) freezes this closed envelope.

**Record results in the retro doc** under a `## Close-Out Sweep`
section: carry-over items closed/partial, escalations resolved or
deferred, any status-yaml drift caught and corrected. If everything
was already closed inline, note "Sweep: clean (all items closed
inline during implementation)".

**Artifact-size audit (Rule 25(d), warn-only here).** Run:

    scripts/validate-artifact-budget.sh --warn-only

Record its output verbatim in the retro doc under `## Artifact-Size Audit`. If it
reports no breaches, note "Artifact sizes: within budgets".

The script owns the canonical budgets and the per-artifact remedy — the numbers
are NOT restated here. A project overrides a budget with `AI_DLC_BUDGET_<NAME>`
(see the script header), not by editing this paragraph.

`--warn-only` is deliberate and is the ONLY posture retro takes. Retro reports on
a sprint that has already paid for every oversized read; blocking it now helps
nobody. **The blocking copy of this check runs at sprint start** (`route.md`
Step 1a), which is the last moment an oversized artifact is still cheap to fix,
plus at gate Check 14 for `pipeline-snapshot.md` — the one artifact that grows
within a sprint. Retro NEVER runs the consolidation itself: it is a
fidelity-critical rewrite and is operator-invoked.

Two breaches deserve a finding in their own right, not just a size warning:
- A **`compaction-log.md`** over budget means the sprint compacted repeatedly, and
  every entry with `recovery_injected: no` is a turn the lead resumed from the
  summary alone.
- A **`pipeline-snapshot.md`** over budget means the schema stopped being enforced
  at gate passages. The gates that let it grow are the finding — not the file.

**Layer-entry audit (Rule 27, warn-only).** On a layered consumer, run
`scripts/validate-layer-entries.sh` and record a `## Layer-Entry Audit` section in
the retro doc with its output. ERRORs are mechanized invariants — a poisoned
`base_sha` (Rule 27(a)) silently disables override-drift detection for that entry,
so the next pull cannot tell whether upstream changed the rule it shadows. WARNs
are smells needing judgement: an extension restating a core section, a restriction
filed in the additive layer, a dangling `Step <n>` pointer. Fix ERRORs before the
next `/ai-dlc-update`; triage WARNs into the backlog. Warn-only — never blocks the
pipeline. On a consumer with no layer directories the script exits clean; note
"Layer entries: n/a (unlayered)".

### 4b. Operator-steerability audit, then flow-log rotation (Rule 29 / Rule 25(c))

The operator must be able to reach the lead mid-section. Two failures make that
impossible, and both are mechanically detectable. **Audit first, rotate second** —
rotating before the audit destroys the evidence the audit reads.

**Audit.** Run the validator against this session's transcript:

    scripts/validate-steering-budget.sh --transcript ~/.claude/projects/<project-slug>/<session-id>.jsonl

- **Check A (starvation)** — any foreground tool call that outlasted the steering
  budget. While it was in flight there was no tool boundary, so a queued operator
  message could not be delivered. The near-universal cause is a dev or analyst
  dispatched blocking instead of bounded-join (Rule 29). Each is a **lead-conduct
  finding**.
- **Check B (steamroll)** — any operator message followed by a pipeline-advancing
  call before the pause flag was released. The lead received a steer and executed
  through it. Each is a **lead-conduct finding**.

Then read the flow log, `_bmad-output/pipeline-continuation-log.md`:

- `ACK_DENIED` — the `PreToolUse` hook had to physically block the lead from
  advancing past a waiting operator. A nonzero count means the lead tried; the
  hook, not the lead's judgment, is what protected the human. Investigate why.
- `USER_PAUSE` vs `BLOCKED` — pause frequency against Rule 3 enforcement volume.
- `BACKOFF` — the Stop hook exhausted its retry budget; the pipeline genuinely
  stuck. Find the upstream cause in the transcript.

A retro that reports zero steerability findings on a sprint in which the operator
visibly repeated themselves has run the audit wrong.

**Rotation.** The flow log is append-only and is a Rule 25(c) log: a live log must
hold only the current epoch, or the audit above reads all of history instead of
this sprint.

After the audit is recorded, rotate — the last write to the log before sprint
close:

    mv _bmad-output/pipeline-continuation-log.md \
       _bmad-output/pipeline-continuation-log-archive-s<N>.md

The live log is NOT recreated by hand. All three hooks (`ai-dlc-pause.sh`,
`ai-dlc-continue.sh`, `ai-dlc-acknowledge.sh`) re-seed the header on their next
write when the file is absent or empty, so the next sprint's first event opens a
clean log. The archive is write-only and never re-read in the hot path.

Rotation is unconditional and per-sprint — not threshold-triggered. A threshold
would let the log carry several sprints of unrelated events into an audit that is
scoped to one.

**Rotate the context-mode protection log the same way.**
`_bmad-output/context-mode-protection-log.md` (written by `ai-dlc-protect.sh`, read
at §1 of this step) is append-only and hook-written; Rule 25(d)'s budget check covers
the class, and this rotates the instance:

    mv _bmad-output/context-mode-protection-log.md \
       _bmad-output/context-mode-protection-log-archive-s<N>.md

Same contract: the hook re-seeds the header on its next write, the archive is
write-only, rotation is unconditional and per-sprint.

## Sprint-Ship Verification

Sprint-ship counters track smoke-quality across deploy-validate runs.

- **`consecutive-deploy-clean`** — increments on each deploy-validate run
  with zero smoke FAILs. Resets to 0 on ANY smoke FAIL, regardless of
  whether the FAIL is new or pre-existing. Strictest counter; reflects
  ship-quality without grandfathering.
- **`consecutive-no-regression`** — increments on each deploy-validate run
  with zero NEW smoke FAILs (pre-existing FAILs may persist without
  resetting this counter). Resets to 0 ONLY on a NEW smoke FAIL not
  present in the prior deploy-validate run. Looser counter; reflects
  whether THIS sprint introduced regressions versus carrying pre-existing
  debt.

Both counters MUST be reported in every retro under the standard template
line:

```
dual-counter: consecutive-deploy-clean: <N>/5; consecutive-no-regression: <M>/5 (run-id: <CI-run-id>).
```

The 5/5 ship-quality target applies to BOTH counters independently. A
sprint is ship-quality when EITHER counter reaches 5/5.

### 5. Human Commentary

Present the retro summary and ask:

"Retro complete. Any comments or questions before I close out the sprint?"

Before ending the turn, mark the pause (Rule 3):
`touch _bmad-output/pipeline-paused.flag`.

Wait for the human's response. If they have commentary:
- Incorporate it into the retro doc
- Apply any additional process changes they request
If they have nothing to add, proceed.

### 5b. Append Audit-Anchor SHA

After human commentary returns and before commit, append a new entry
to `_bmad-output/audit-anchors.md` with the current sprint's
retro-PR-merge SHA placeholder. The merge SHA is unknown until the
retro PR merges; lead writes the entry with sprint + closed_at fields
and updates the SHA in a follow-on commit on `main` after merge.

The schema is canonical in `.claude/schemas/audit-anchors.json` — NOT the live
header or the template. Re-seed the header first: replace the file's
`BEGIN GENERATED: audit-anchors-schema … END GENERATED` region with the output
of `scripts/validate-audit-anchors.sh --render` (a new file gets that whole
block), then append the entry below `## Entries` in the shape it documents. Do
NOT hand-write the header. Step 5c runs `scripts/validate-audit-anchors.sh`,
which fails the commit on header drift or a malformed entry. No SHA for the
prior sprint = audit-gate fails closed at the next sprint's per-class test-debt
audit (`gate-validation.md` Check 18).

### 5c. Pre-Commit Validation Gate

Before committing retro artifacts, run all four checks in order.
Failure on any check blocks the Step 6 commit.

**Gate type for validation loading (Rule 21 / Lever 2).** This is the
`retro` gate. When running gate validation (`gate-validation.md`) at
sprint close, declare it `run gate validation [retro]` so the loader
loads the retro slice (universal core + Checks 8, 9, 17,
core-layer-immutability).

1. **Rule file audit commit.** If the rule file audit (Step 4)
   produced file changes, commit them NOW as a separate commit:
   `docs(rules): rule file audit (retro) — strip narrative, harden weak rules`.
   If the audit was clean, skip.

2. **Provenance block verification.** Open the retro doc and verify
   the `SKILL_INVOCATION_PROVENANCE v1` block cites a valid
   `tool_use_id`. If the tool_use_id is NOT_ACCESSIBLE (common after
   compact), that is acceptable — note it in the provenance block.
   If the provenance block is missing entirely, add it now before
   proceeding.

3. **Mandatory rules validation.** Run:
   `scripts/validate-mandatory-rules.sh <N>` (where N is the sprint
   number). It runs `validate-retro-evidence.sh` (Check 1) and inline
   Checks 3/5/6; Checks 2 (`validate-cycle-commits.sh`) and 4
   (`validate-retro-prereq.sh`) are consumer-provided and SKIP when their
   sibling script is absent from core. Check 3 reads the envelope you closed
   in the Close-Out Sweep above via `sprint-status.sh close`.
   (`validate-provenance-block.sh` is run separately — at Step 5c check 2
   above locally, and as its own CI step.) MUST exit 0. If it fails, fix the
   issues before proceeding to Step 6.

4. **Audit-anchor schema validation.** Run
   `scripts/validate-audit-anchors.sh _bmad-output/audit-anchors.md`. It
   fails closed if the Step-5b header drifted from the canonical schema
   (`.claude/schemas/audit-anchors.json`) or the appended entry is malformed.
   MUST exit 0 — a drifted housekeeping schema is the defect this check exists
   to catch, not a clean file.

### 6. Commit, Push, and PR

**6a. Commit all remaining artifacts.**

**Pre-commit completeness check.** Before staging, verify these
artifacts exist for this sprint. Missing items indicate a skipped
step — go back and complete it before committing:

- [ ] Gate-log entry exists in `_bmad-output/implementation-artifacts/gate-log.md` for this sprint
- [ ] `_bmad-output/audit-anchors.md` updated (Step 5b)
- [ ] Next-sprint prompt emitted (Step 7) OR "no next sprint" stated explicitly
- [ ] Retro doc has provenance block citing party-mode transcript

If any item is missing, complete the skipped step NOW before
proceeding. Do not commit an incomplete retro.

Run `git status` to identify any uncommitted files. Stage and commit
everything produced during the sprint that hasn't been committed yet.
This typically includes:

**Implementation artifacts** (if not already committed per-story):
- `_bmad-output/implementation-artifacts/gate-log.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `docs/reviews/*.md` (code review output)
- `docs/escalations/pending.md` (escalation entries)

**Retro artifacts** (produced in steps 3-5 above):
- `docs/retro/sprint-N.md` (the retro document)
- Any files modified by process improvements (CLAUDE.md, team roles,
  coding-conventions.md, pipeline step files)
- `docs/ai-dlc-feedback.md` (if updated)

**Close-out sweep artifacts** (produced in step 4a above):
- `_bmad-output/planning-artifacts/carry-over-backlog.md` (closures)
- `docs/escalations/pending.md` (resolutions and deferrals)
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
  (any drift corrections)

Use a conventional commit message:
`docs(retro): sprint N retrospective, reviews, and process improvements`

If there are no uncommitted changes, skip this step.

**6b. Push the branch.**

Push the current branch to origin:
```bash
git push -u origin HEAD
```

**6c. Determine if a PR is warranted.**

Check the current branch:
- If on `main` or `master`: No PR needed — work was committed directly.
  Announce: "Sprint [N] complete. Pipeline finished."
- If on any other branch: A PR is warranted. Proceed to 6d.

**6d. Create a pull request.**

Generate a PR using the sprint's artifacts as the source material:

- **Title:** Short description of the work (under 70 characters).
  Derive from the pipeline variant and user's original request.
  Examples: "Add user dashboard with real-time metrics",
  "Fix stale cache in search results"

- **Body:** Use the following structure, populated from sprint artifacts:

  ```
  ## Summary
  [2-5 bullet points describing what was built/fixed, derived from
  the sprint stories and retro summary]

  ## Pipeline
  - **Variant:** [pipeline variant]
  - **Stories:** [count] delivered
  - **Gate log:** see `_bmad-output/implementation-artifacts/gate-log.md`

  ## Autonomous Decisions
  [List any DECIDED_AUTONOMOUSLY entries from docs/escalations/pending.md,
  or "None" if clean]

  ## Test Evidence
  [Brief summary of test coverage — smoke tests, production integrity
  tests, QA validation results]

  ## Retro Highlights
  [1-3 key findings from the retrospective, if notable]
  ```

- Create the PR with `gh pr create` targeting the main branch.
- If `gh` is not available, provide the user with the branch name
  and suggest they create the PR manually.

**6e. Announce completion.**

Present to the user:
- PR URL (if created)
- Sprint summary (stories delivered, gate results)
- Any open escalations that need human review

Announce: "Sprint [N] complete. Pipeline finished."

### 7. Merge and Next-Sprint Handoff

This step closes the loop on the sprint and produces a copy-pasteable
`/ai-dlc` prompt for the next sprint. The prompt is authored here, not
in the next sprint's discovery step, so that retro findings, unfinished
epic scope, and residual risks are still in the lead's working context.

**7a. Merge gate.**

- **If a PR was created in 6d:**
  Ask the user: "Merge PR [#N] now? (y/n)"
  - **y:** Run `gh pr merge <N> --squash --delete-branch` (use the merge
    strategy the repo's PRs normally use; check recent merges with
    `gh pr list --state merged --limit 3 --json number,title,mergedAt`
    if unsure). If merge fails (branch protection, failing checks,
    conflicts), surface the error and stop — do not emit the next-sprint
    prompt until the user resolves and confirms merge.
  - **n:** Do not merge. Emit the next-sprint prompt immediately with a
    one-line preamble noting the PR is still open and the user should
    paste the prompt after it merges.
- **If no PR was created (direct-to-main in 6c):** Skip the merge gate
  and proceed directly to 7b.

**7b. Assemble next-sprint inputs.**

Issued AFTER the 7a merge gate (a human y/n seam — no dispatch before
Step 5 can cover post-merge inputs, §2 blocker 2). If `planning_offload:
on`, dispatch an `analyst` subagent (Agent tool, bound to the analyst role file `.claude/team-roles/analyst.md` per SKILL.md Rule 19 — both bindings: `model` and the standing role-contract Read line)
— **Dispatch B** — to gather all six input classes below (including the
relatedness analysis in input 6) and write the structured bundle to
`_bmad-output/retro-artifacts/sprint-<N>-next-inputs.md`, returning only
`{artifact_path, summary, gaps}`. The lead derives the theme (7c) and
authors the paste-able prompt (7d) from that bundle **plus its own
retained retro findings** — the Step-3 improvements and Step-4
dispositions stay resident because the lead decided them; only the raw
file reads move to the analyst. If `planning_offload: off`, gather
inline. Per SKILL.md Rule 24.

Gather the material the next-sprint prompt will draw from. Read, do not
summarize prematurely:

1. **Current epic state.** Read the active epic file under
   `_bmad-output/planning-artifacts/` (epic files are created by
   `/bmad-create-epics-and-stories` in `stories-test-strategy.md`).
   Determine:
   - Which stories in the epic are `done` vs remaining
   - Whether the epic is complete (all stories done) or in-progress
   - Any epic-level acceptance criteria not yet satisfied
2. **Carry-over candidates.** From `_bmad-output/implementation-artifacts/sprint-status.yaml`,
   list any stories with status `blocked`, `deferred`, or `skipped` that
   have a rationale indicating they should return in a future sprint.
3. **Open escalations.** From `docs/escalations/pending.md`, list any
   entries not resolved during this sprint.
4. **Unexercised gates.** Any CI gate declared in `docs/retro/sprint-N.md`
   (this sprint's retro) that has not yet run green on a PR — these must
   be exercised in the exercise window or the next retro fails (see
   "Empirical gate validation" above).
5. **Retro improvements with sprint-N+1 follow-ups.** Any action items
   in `docs/retro/sprint-N.md` tagged for the next sprint (e.g.,
   "Sprint N+1 task to add weekly schedule cron" from the path-filter
   dormancy scan).
6. **Related-epic scope candidates.** From the broader epics list in
   `_bmad-output/planning-artifacts/`, identify epics that are directly
   related to the current epic (shared components, adjacent user flows,
   or explicit dependency links). These are potential scope for the
   next sprint IF the current epic is complete or nearly so.

**7c. Derive the next-sprint theme.**

Priority order when choosing the theme:

1. **Current epic not complete** → theme = continue/finish the current
   epic. Scope = remaining epic stories + any carry-over or retro
   follow-ups that block epic completion.
2. **Current epic just completed this sprint** → theme = consolidate +
   advance. Scope = retro follow-ups, unexercised gates, open
   escalations, and the most directly-related next epic as stretch
   scope.
3. **Current epic was already complete before this sprint** (sprint was
   pure carry-over or cross-cutting work) → theme = next epic in the
   prioritized list. Scope = that epic's first stories + open
   escalations.

The theme is one sentence, stated as the sprint's objective (not a
summary of inputs).

**7d. Emit the handoff block.**

Present the following verbatim to the user. The `----` lines are the
copy-paste boundaries the user requested; do not add any other content
between them.

```
Sprint [N] closed.

Next sprint theme: [one-sentence theme derived in 7c]

Scope outline (for context, not part of the prompt):
- Current epic: [epic name] — [complete | N of M stories remaining]
- Carry-over: [count] stories  ([list IDs or "none"])
- Open escalations: [count]   ([list IDs or "none"])
- Unexercised gates: [list or "none"]
- Retro follow-ups: [list or "none"]
- Related-epic stretch scope: [list or "none"]

Copy the prompt below to start the next sprint.

----
/ai-dlc

[Draft prompt body — written in the same voice the user would use.
 Lead with the theme. Then name the epic explicitly and say whether
 the goal is to continue it or close it out. Then enumerate the
 in-scope items from 7b in priority order: epic-remaining stories
 first, then carry-over, then retro follow-ups and gate exercises,
 then related-epic stretch scope last (marked "stretch"). Keep it
 under ~15 lines. Do not restate already-done work.]
----
```

Replace the bracketed placeholders with actual content. The prompt body
between the `----` markers must be directly pasteable — no meta
commentary, no "here is your prompt", no surrounding quotes.

Mark the pause before ending the turn (Rule 3 — the snapshot outlives
the sprint, so without the flag the Stop hook blocks this terminal
turn): `touch _bmad-output/pipeline-paused.flag`.

**STOP.**
