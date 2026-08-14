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
`scripts/ai-dlc/validate-mandatory-rules.sh` expects:

```bash
git checkout -b ai-dlc/retro/sprint-<N>
```

The branch name MUST contain `sprint-<N>` (literal word "sprint"
followed by the sprint number). Abbreviated forms (`s<N>`,
`retro-<N>`) cause validation failures because the script's
branch-detection regex requires the `sprint-<N>` substring.

Branch creation stays inline — it is a git mutation (Rule 28(a) / Rule
23(c): mutations run native, never through a subagent that discards the FS).

**Analyst dispatch binding — read once, applies to every dispatch in this
file.** Where a step below says "dispatch an `analyst`", it means: the Agent
tool, bound to the analyst role file `.claude/team-roles/analyst.md` per
SKILL.md Rule 19 — both bindings, `model` and the standing role-contract Read
line. The subagent writes its artifact and returns only
`{artifact_path, summary, gaps}`; an absent artifact at the returned path is
non-delivery → the lead re-dispatches. Every dispatch is conditional on
`planning_offload: on` (the default); with it `off`, the lead does that read
inline. Per SKILL.md Rule 24.

The sprint-artifact read is NOT issued here. It is folded into the Step-3
dispatch, which needs the same corpus plus the party-mode transcript that does
not exist until Step 2 closes.

Run auto-handoff evaluation at `Seam E` with the label
`retro Step 1 pre-flight` (see `_gate-procedures.md` \"Auto-handoff
evaluation\"). If evaluation returns FIRE, the session ends;
otherwise continue to Step 2.

### 2. Party Mode Retro

Execute all sub-skills back-to-back without pausing for human input
between them.

**Invoke `/bmad-party-mode --mode subagent --non-interactive` via the Skill tool.**
The Skill invocation
IS the satisfier for this step — role-playing PM/Architect/Dev/SM/
TEA/QA perspectives inline in the retro doc without invoking the
Skill is a Rule 20 violation per SKILL.md, regardless of how
well-formed the output appears. This is non-negotiable.
Each agent MUST be spawned as a real subagent for independent perspective. Solo mode (roleplaying agents inline) is forbidden.
**The flags are what make that true — the sub-skill's own default is solo.**
SKILL.md Rule 20 (i) owns why; pass both, every time.
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
   block (schema in `.claude/schemas/provenance-block.json`) is written to the retro doc
   citing the invocation's `tool_use_id`, `invoked_at` timestamp,
   `mode` (always `subagent` — solo is rejected by
   `validate-provenance-block.sh`), and `transcript_path`.

2. **Transcript file commit.** The party-mode transcript (all agent
   responses in full, not summarized) is committed to
   `_bmad-output/party-mode-transcripts/s<N>/retro.md`. This
   file is the byte-for-byte authoritative record; the retro doc's
   "Agent findings" section in Step 3 summarizes but does not
   replace it.

3. **Provenance block cites transcript@sha.** The provenance block's
   `transcript_path` field uses the `path@<sha>` format where
   `<sha>` is the **commit** SHA of the commit that added the transcript
   — NOT the blob SHA. `scripts/ai-dlc/validate-retro-evidence.sh` resolves the
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

<!-- BEGIN GENERATED: provenance-block/retro-party-mode — source: .claude/schemas/provenance-block.json; do not edit by hand -->
```
<!-- SKILL_INVOCATION_PROVENANCE v1
skill: bmad-party-mode                      # the evaluation that ACTUALLY RAN. Naming one you did not invoke is a forged block.
invoked_at: <ISO 8601 UTC, to the second>   # Check 24 orders the pass series on this. Ambiguity here reorders the cycle.
tool_use_id: <toolu_... — from the Skill tool response, or the Agent dispatch that spawned you> # the id of the Skill/Agent call that ran this evaluation. CHECKED FOR SHAPE ONLY — nothing verifies it against a transcript, so it is not proof the evaluation ran.
mode: subagent                              # never solo.
lead_role: <the step file that invoked or dispatched the evaluation> # which step owns this pass.
transcript_path: <_bmad-output/party-mode-transcripts/s<N>/retro.md@<sha>> # required for retro party-mode; byte-matched by validate-retro-evidence.sh.
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

**Doc split (Dispatch A — Rule 24).** Dispatch an `analyst` to read the sprint
corpus and draft the **descriptive/analytical** sections only — the sprint
summary, `hard_block_count` + `hard_block_class[]`, and the **Agent-findings
summary**. It reads:
- Sprint stories in `_bmad-output/planning-artifacts/s<N>/stories/`
- Code reviews in `docs/reviews/`
- Gate log at `_bmad-output/implementation-artifacts/gate-log.md`
- Escalation log at `docs/escalations/pending.md`
- Sprint-status.yaml
- Context-mode protection log at `_bmad-output/context-mode-protection-log.md` (if it exists)
- The committed party-mode transcript from Step 2

and writes the draft to
`_bmad-output/retro-artifacts/s<N>/retro-draft.md`. Two hard
constraints on that draft:
- The Agent-findings summary MUST cite the existing `transcript_path:
  path@<sha>` verbatim and summarize that already-byte-cited transcript.
  It NEVER re-derives party-mode findings from scratch (that path is
  solo-mode-by-proxy, a Rule 20 violation).
- The analyst NEVER writes a `SKILL_INVOCATION_PROVENANCE` block (Rule
  24: the analyst produces inputs, not validated outputs; the provenance
  block stays the lead's, written in Step 2 / verified in Step 5c).

The **prescriptive** sections stay lead-authored inline — they are the
retro's decision content (pipeline self-governance), as non-delegable as
gate decisions: "specific, actionable improvements," "improvement routing,"
and the Step-4
5-layer enforcement decisions. The lead assembles the analyst draft and
its own prescriptive sections into the final retro doc.

Write the retro to `docs/retro/s<N>/retro.md` with:
- Sprint summary (planned vs delivered, rework cycles, autonomous decisions)
- `hard_block_count` (integer): total HARD_BLOCKs encountered this sprint
- `hard_block_class[]`: list of HARD_BLOCK classifications (e.g., requirement-divergence, scope-conflict, infra-outage)
- Agent findings (from party mode)
  with finding-class per pass (see templates/retro-finding-class-tracking.md)
- Specific, actionable improvements
- Improvement routing: which improvements update CLAUDE.md, team roles, or pipeline steps

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

**Ordering is load-bearing.** This audit MUST see post-improvement file
state, so it runs only after the "apply process improvements" edits
above land (§2 blocker 1) and before the Step-5c audit commit.

Detection is mechanical and is not dispatched. Run:

    scripts/ai-dlc/audit-rule-files.sh

The script owns the scan corpus and the detection regexes — neither is
restated here, where they would drift from the thing that runs. It reports
six scans: narrative drift (Class 1), an incomplete Rule 26(c) triple
(Class 1b), rule weakness (Class 2), complexity accretion (Class 3),
relocation-pointer resolution, and path-filter dormancy. Exit 0 = every
mechanized scan clean; exit 1 = findings; exit 2 = the scan could not be
performed, which is never a pass.

**Class 3 always reports `DID-NOT-RUN`, and that is correct.** Complexity
accretion needs each gate's catch/false-positive history since introduction,
which no static scan holds. It is the lead's, every retro: for each gate,
check, hook, guard, or rule added in a prior sprint, confirm it carries the
Rule 26(c) contract (concrete failure caught, false-positive cost, removal
condition) and that its false positives since introduction do not exceed its
true catches. Record the tally per finding and propose removal or narrowing
as a process improvement — machinery is removed through the same Step 4
mechanism that added it.

**The lead dispositions every finding and authors every rewrite inline.**
Rule rewriting is a governance judgment expressed as text, tightly coupled
to disposition; routing the decided text-insertion to a dev is pure overhead
(Rule 26: no dispatch hop for a decision the lead already made). Per finding:

- Is the text part of a rule statement (prescriptive/directive), or prose
  explaining how something works (descriptive)? Descriptive prose is exempt.
- For narrative drift: does the bare rule still make sense when the
  narrative is removed?
  - **Yes** → strip the narrative; the WHY goes to the audit commit message.
  - **No** → the rule is leaning on the story. Rewrite it hard (see
    Rule 18 style), or mark for removal and raise during Step 5 human
    commentary.
- For rule weakness: rewrite the rule using imperative or MUST/MUST NOT/SHALL.
  If the soft language was intentional (genuine advisory preference), the
  rule does not belong in rule files — move it to the retro doc as a lesson
  or remove it.
- A dangling pointer is a HARD_BLOCK: restore the target or correct the
  pointer before the Step 5c audit commit.
- A dormant CI job MUST get a remediation path, not a report: either cite an
  existing `schedule:` cron trigger that exercises it independent of path
  filters, or file a Sprint N+1 task to add a weekly one. A dormancy finding
  without remediation is narrative drift.

Record the verdicts in the `## Machine Audits` table (below), and the
dispositions — rules rewritten, rules marked for removal, accretion tallies —
under `## Rule File Audit`.

If the audit produced file changes, do NOT commit them yet — Step 5c
handles the audit commit as a separate commit before the main retro
commit in Step 6.

#### Resident-ordering scan (every retro)

Resident-context slimming relocates rule bodies out of `SKILL.md` into JIT
files. Pointer resolution is covered by `audit-rule-files.sh` above. Two
further invariants MUST hold each retro; both are HARD_BLOCK on failure and
MUST be fixed before the Step 5c audit commit.

**1. The POST-COMPACT RECOVERY PROTOCOL fits inside the re-attach window.**
Claude Code re-attaches only the first ~5,000 tokens of `SKILL.md` after
compact, and a protocol truncated by the event it handles is worthless. Run:

    scripts/ai-dlc/validate-reattach-budget.sh

It FAILS if the protocol's END offset exceeds the ceiling; a non-zero exit is
a hard audit failure. Its slack figure is measured against that ceiling, so it
is the headroom the next addition to `SKILL.md` actually has. Rules 21–26, INITIALIZATION, and
`## HANDOFF PROTOCOL -- TRIGGERS AND CONTEXT THRESHOLDS` are second-tier by
the file's own design ("may sit past the 5K boundary") and are NOT required
within the window.

**2. Every `GATE_MANIFEST` check ID resolves to a live check anchor, and
every check anchor is claimed by the manifest.** Gate-type slicing loads
checks by gate type; a manifest ID with no matching check, or a check with no
manifest claim, silently mis-slices a gate — it runs, reports PASS, and the
missing check never fires. Run:

    scripts/ai-dlc/validate-gate-manifest.sh

It derives both directions from the manifest and hard-codes no check ID. It
resolves the RENDERED manifest, not core's: an `overrides/` entry shadowing the
manifest section supplies the table, and `extensions/` entries hooking this file
supply anchors. MISSING and ORPHAN must both be empty, and the `manifest source:`
line must name the layer the table actually came from. Exit 2 means the resolve
could not be performed (no anchors, no rows, no `universal` row, two overrides
each carrying a table, or an override that shadows the section away) and is never
a pass.

### Empirical gate validation

Every gate added via retro MUST be exercised on a green run within the next
PR that naturally touches the gate's enforcement domain. Absence of exercise
within that window fails the next retro. Shipping a gate wired to no workflow
trigger, or wired only to a workflow that does not run on any PR in the
exercise window, is the dormant-gate anti-pattern.

Enforcement: `scripts/ai-dlc/validate-ci-gates.sh` scans `docs/retro/**/*.md`
for declared gate names and matches each against an enforcement surface; any
declared gate with no match is flagged as DORMANT and the run exits non-zero.
Retro authors MUST ship the gate's wiring in the same PR as the retro's gate
declaration, or cite the wiring PR that did.

**A consumer with no `.github/workflows/` MUST declare its surface, and doing
nothing is not the local option.** The script has two ways to adjudicate a gate
and a project needs at least one of them:

- `AI_DLC_CI_SURFACE` — the directory that actually holds the gates, when CI
  lives somewhere other than `.github/workflows/`.
- `AI_DLC_CI_ALIAS_TABLE` — a file of `gate|enforcer_id|enforcing_file|anchor`
  rows, for a project whose gates are enforced LOCALLY (a pre-push hook, a
  script). This path consults only the files the rows name, so it adjudicates
  in full with no CI directory present at all.

With neither, the run is VACUOUS (exit 78) and **prints every declared gate
name it could not check** — that inventory is the deliverable in that case, and
§4's unexercised-gate audit reads it. Measured on the reference consumer before
this was so: six unique gate names declared across 14 retro files, none of them
ever enforcement-checked, because the validator returned 78 before reading a
single retro and named nothing.

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

**Close-Out gather (Dispatch B).** Dispatch an `analyst` to RUN and MATCH —
never to dispose. It writes its tables to
`_bmad-output/retro-artifacts/s<N>/closeout-tables.md`:
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
  `scripts/ai-dlc/validate-layer-entries.sh` and returns its errors/warnings. Skip on a
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
batch is large.

**Deferral-justification triple (MANDATORY).** Every carry-over deferral,
re-affirmed deferral, passive monitor, and sprint-cut deferral surfaced at
close-out MUST fill all three slots. Any unfillable slot reclassifies the item
BEFORE the production validation checkpoint (PVC) — close it, or do it now.
The lead is the detector, not the operator:

- **TRIGGER** — the specific in-sprint diff or path that creates the need,
  cited `file:line`. No citable trigger → the item is INVALID; delete it, do
  not carry it.
- **EFFORT-BLOCKER** — what concretely prevents in-sprint delivery, with an
  estimate. If the work is below an OBJECTIVE bright-line — a ≤~10-line config
  edit, or the deletion of a single artifact — it is IN-SCOPE NOW, not a
  deferral. The bright-line MUST be objective, never "lead judgment".
- **CONDITION** — the runnable test, anchor, query, or observable, re-verified
  LIVE at close-out. Run the cited test, query the cited source, read the
  monitored signal. If it is now satisfied (test green where it was held red,
  event observed, value in-band), the item is reclassified
  `CLOSED - delivered in sprint <N>` / `CLOSED - satisfied` with the
  verification evidence cited — NOT carried, NOT re-deferred.

A deferral whose target is already delivered, or whose premise was never
triggered, or that conceals trivially-doable work, is a vacuous deferral.
Surfacing one at the PVC, where the operator rather than the lead discovers
it, is a close-out failure. A deferral surviving all three slots is presented
at the PVC with its triple as evidence — a stress-tested deferral the operator
reviews, not one the operator must detect.

Record each item's triple (item, trigger, effort-blocker, condition + LIVE
result) in the retro `## Close-Out Sweep` section.

**Minimum mechanism (Rule 26(c)).** Failure caught: an untriggered,
trivially-doable, or already-satisfied deferral reaching the operator at the
PVC. False-positive cost: filling three short slots per surviving deferral,
one of which re-runs an already-runnable check (a still-unmet condition simply
confirms the carry). Removal condition: retire when successive retros record
zero unfillable slots and zero reclassifications. Violation: any deferral or
carry-over surfaced at the PVC without its triple, or the operator (not the
lead) catching a vacuous deferral → retro finding.
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

       scripts/ai-dlc/sprint-status.sh close \
         --evidence "<what proves the sprint closed: PR/merge, deploy, smoke>" \
         --retro-doc docs/retro/s<N>/retro.md

   This flips `status: done` and writes the `sprint_<N>_housekeeping:` block
   (`envelope_status: done` + non-empty `closure_evidence`) that Step 5c's
   `validate-mandatory-rules.sh` Check 3 reads — the ONLY writer of that block
   (`.claude/schemas/sprint-status.json`), write-verified and idempotent. The next
   sprint's `roll` (route.md Step 6) freezes this closed envelope.

**Record results in the retro doc** under a `## Close-Out Sweep`
section: carry-over items closed/partial, escalations resolved or
deferred, any status-yaml drift caught and corrected. If everything
was already closed inline, note "Sweep: clean (all items closed
inline during implementation)".

**Artifact-size audit (Rule 25(d), warn-only here).** Run:

    scripts/ai-dlc/validate-artifact-budget.sh --warn-only --fail-on pipeline-snapshot.md

The script owns the canonical budgets and the per-artifact remedy — the numbers
are NOT restated here. A project overrides a budget with `AI_DLC_BUDGET_<NAME>`
(see the script header), not by editing this paragraph.

`--warn-only` is deliberate for the PLANNING artifacts. Retro reports on a sprint
that has already paid for every oversized read; blocking it now helps nobody.
**The blocking copy of this check runs at sprint start** (`route.md` Step 1a),
which is the last moment an oversized artifact is still cheap to fix, plus at
gate Check 14 for `pipeline-snapshot.md` — the one artifact that grows within a
sprint. Retro NEVER runs the consolidation itself: it is a fidelity-critical
rewrite and is operator-invoked.

**`pipeline-snapshot.md` is the one exception, and `--fail-on` is how retro says
so.** The warn-only reasoning is about artifacts whose growth is monotonic by
construction — nothing retires a locked requirement, so blocking on them at retro
offers no action. It does not transfer to the snapshot, which is trimmable BY
DESIGN: its remedy is to move superseded entries to the write-only history file,
and retro is the passage where that happens. A ceiling nobody is ever blocked by
is a number, not a ceiling. So the snapshot takes a hard verdict while every
other artifact in the same run stays a warning.

That hard verdict covers three independent findings, and each carries its own
remedy rather than being folded into a size number: over budget, a section
outside the seven-section schema, and **superseded content marked in place rather
than moved**. The third is the one nothing else catches — struck, bracketed, or
all-caps-stamped content sits under a canonical heading at any size, so the schema
check and the byte budget both pass it in silence, and the size remedy then says
"trim" when the correct action is "relocate".

Two breaches deserve a finding in their own right, not just a size warning:
- A **`compaction-log.md`** over budget means the sprint compacted repeatedly, and
  every entry with `recovery_injected: no` is a turn the lead resumed from the
  summary alone.
- A **`pipeline-snapshot.md`** over budget means the schema stopped being enforced
  at gate passages. The gates that let it grow are the finding — not the file.

**Layer-entry audit (Rule 27, warn-only).** On a layered consumer, run
`scripts/ai-dlc/validate-layer-entries.sh`. ERRORs are mechanized invariants — a poisoned
`base_sha` (Rule 27(a)) silently disables override-drift detection for that entry,
so the next pull cannot tell whether upstream changed the rule it shadows. WARNs
are smells needing judgement: an extension restating a core section, a restriction
filed in the additive layer, a dangling `Step <n>` pointer. Fix ERRORs before the
next `/ai-dlc-update`; triage WARNs into the backlog. Warn-only — never blocks the
pipeline. On a consumer with no layer directories the script exits clean.
<!-- inline-ok: a layer-entry ERROR is repaired by the lead inline, not dispatched. The subject is a `.claude/ai-dlc-layer/` registry entry — the project's own record of which core rules it shadows — not a planning artifact, and the disposition and the edit are one act: deciding that a `base_sha` is poisoned IS deciding what to write in its place. Routing the decided value to a dev is the dispatch hop Rule 26 names, the same posture as the rule-rewriting carve-out earlier in this step. -->

#### `## Machine Audits` — one table, not five transcriptions

Every scan above reports into ONE `## Machine Audits` table in the retro doc.
Do NOT paste a clean run's output: a PASS's detail is reproducible by
re-running the script, and five verbatim blocks per retro is the sprint's
largest single writing cost for its least-read content.

| check | verdict | evidence |
|-------|---------|----------|
| `audit-rule-files.sh` | PASS / FINDINGS | exit code + each class's verdict line |
| `validate-reattach-budget.sh` | PASS / FAIL | exit code + the slack figure, read against the guard's ceiling |
| `validate-gate-manifest.sh` | PASS / FAIL | exit code + the `manifest source:` and `anchor sources:` lines + the MISSING/ORPHAN/UNLOADABLE lines |
| `validate-artifact-budget.sh --warn-only --fail-on pipeline-snapshot.md` | CLEAN / BREACH | exit code + each breached artifact, and the run's own final summary line verbatim; a nonzero exit here is the snapshot's hard verdict (budget, schema, or in-place supersession marker). **Exit 0 is not by itself CLEAN under `--warn-only`** — the summary line says which, and it is `WARN  this run reported …` when anything was reported |
| `validate-layer-entries.sh` | CLEAN / N ERR, M WARN | exit code + the summary line, or "n/a (unlayered)" |

**The evidence cell is mandatory and is never `—`.** An empty evidence cell is
not a passing record — it is indistinguishable from a check that never ran, and
that is the failure this table exists to make impossible. A row whose verdict is
anything but clean expands to its full output immediately below the table; a
clean row does not.

A scan that could not run (`gh` absent, exit 2, N/A) records that verdict
verbatim with its reason. SKIPPED and N/A are NOT clean.

### 4b. Operator-steerability audit, then flow-log rotation (Rule 29 / Rule 25(c))

The operator must be able to reach the lead mid-section. Two failures make that
impossible, and both are mechanically detectable. **Audit first, rotate second** —
rotating before the audit destroys the evidence the audit reads.

**Audit.** Run the validator across every transcript in the SPRINT window, not this
session's:

    scripts/ai-dlc/validate-steering-budget.sh \
      --dir ~/.claude/projects/<project-slug>/ \
      --since <ISO-8601 UTC of the sprint's first commit>

Record the reported `transcripts scanned : N` in the retro. **N must be greater than 1 on
any sprint that handed off or auto-compacted**, and a scan of 1 on such a sprint is a
mis-scoped audit, not a clean one. The findings here are sprint-level lead-conduct
findings, but a sprint does not run in one session: every handoff and every auto-compact
starts a new transcript file, so a single-session scan cannot fail for anything before the
last compaction — which in a long sprint is most of it. That is the vacuous-pass shape, and
it is worse than an unrun check because it produces a PASS the retro then cites.

- **Check A (starvation)** — any foreground tool call that outlasted the steering
  budget. While it was in flight there was no tool boundary, so a queued operator
  message could not be delivered. The near-universal cause is a dev or analyst
  dispatched blocking instead of bounded-join (Rule 29). Each is a **lead-conduct
  finding**.
- **Check B (steamroll)** — any operator message followed by a pipeline-advancing
  call before the pause flag was released. The lead received a steer and executed
  through it. Each is a **lead-conduct finding**.

Then read the flow log, `_bmad-output/pipeline-continuation-log.md`. **Count entries with
`grep -c '^## .*-- <EVENT>'`, never a bare `grep -c <EVENT>`** — the log's own header
legend names every event type, so the bare form counts documentation as data and inflates
the tally by the number of times the header mentions the token. The inflated figure is
plausible (a bare `grep -c BACKOFF` returns 3 on a log holding zero BACKOFF events), so
nothing about the result signals that it measured the wrong thing:

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

    mkdir -p _bmad-output/implementation-artifacts/s<N>
    mv _bmad-output/pipeline-continuation-log.md \
       _bmad-output/implementation-artifacts/s<N>/pipeline-continuation-log-archive.md

**Every rotation archive lands at `implementation-artifacts/s<N>/<log>-archive.md`,
including the logs whose live copy sits at `_bmad-output/` root.** The directory is
the only sprint slot (`artifact-path-grammar.md`), so the archive's basename carries
no sprint token and there is one destination rule rather than one per log.

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

    mkdir -p _bmad-output/implementation-artifacts/s<N>
    mv _bmad-output/context-mode-protection-log.md \
       _bmad-output/implementation-artifacts/s<N>/context-mode-protection-log-archive.md

Same contract: the hook re-seeds the header on its next write, the archive is
write-only, rotation is unconditional and per-sprint.

**Discard the retro scratch directory.** `_bmad-output/retro-artifacts/` holds
this step's dispatch inputs — the retro draft, the close-out tables, the
next-sprint bundle. Every one of them has already been consumed and its
conclusions committed in `docs/retro/s<N>/retro.md`, which is the record. They
are scratch, not a log, so Rule 25(a)'s no-loss archive duty does not apply and
they are deleted rather than rotated:

    rm -rf _bmad-output/retro-artifacts

Unrotated, this directory accumulates every sprint's inputs forever — measured
at 61 files / 1.0 MB on the reference consumer, growing ~77 KB per sprint, read
by nothing after the dispatch that wrote it returned.

**Two more logs rotate at Step 7a-post, not here.** `gate-log.md` and
`compaction-log.md` must wait until the retro PR has merged — see 7a-post for
why. This section is not the whole rotation set.

### Sprint-Ship Verification

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

Each counter is tracked against its own 5/5 target. A sprint is
ship-quality when EITHER counter reaches 5/5.

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

That follow-on commit is the one THIS step licenses to reach `main` outside a
PR — not a count of the pipeline's out-of-PR commits. §7a-post commits the log
rotation direct to `main` too, for the reason stated there, and a consumer may
license more; each such commit is licensed by the step that states why a PR
cannot carry it. This one edits `_bmad-output/audit-anchors.md` and nothing
else, and its subject MUST be:

`chore(s<N>): backfill audit-anchor SHA after retro PR #<PR> merge`

`scripts/ai-dlc/validate-audit-anchors.sh --trunk-push` runs in the
pre-push hook and rejects the push if that commit carries any other path,
or if a commit rewrites `audit-anchors.md` alone under any other subject.
It bounds this commit only and states no branch policy — so put nothing else
in it: other retro changes go in the retro PR, and a commit another step
licenses stays with that step.

The schema is canonical in `.claude/schemas/audit-anchors.json` — NOT the live
header or the template. Re-seed the header first: replace the file's
`BEGIN GENERATED: audit-anchors-schema … END GENERATED` region with the output
of `scripts/ai-dlc/validate-audit-anchors.sh --render` (a new file gets that whole
block), then append the entry below `## Entries` in the shape it documents. Do
NOT hand-write the header. Step 5c runs `scripts/ai-dlc/validate-audit-anchors.sh`,
which fails the commit on header drift or a malformed entry. No SHA for the
prior sprint = audit-gate fails closed at the next sprint's per-class test-debt
audit (`gate-validation.md` Check 18).

**A sprint that ends WITHOUT a retro-PR merge still owes an anchor.** A sprint
reset or abandoned after its number was consumed reaches neither this step nor a
merge SHA, so it used to leave a hole — and a hole and a missing anchor are the
same observation, which is why Check 18 fails closed on both and why clearing one
took an operator override. Write the close record instead:

`scripts/ai-dlc/validate-audit-anchors.sh --close-record _bmad-output/audit-anchors.md <N> <reset|abandoned> <sha>`

`<sha>` is the commit the sprint actually STOPPED at, and it must resolve — the
next sprint's audit window opens there. The mode refuses a reason outside the
schema's closed set, an unresolvable or PENDING sha, and a second entry for a
sprint that already has one. It fills the hole; it does not waive the anchor, and
Check 18 still fails closed when no entry exists at all.

**Then prune (Rule 25(a)/(c)).**

1. Keep the **3 most recent** entries in `_bmad-output/audit-anchors.md`.
2. Move every older entry, verbatim cut-and-paste, to
   `_bmad-output/audit-anchors-archive.md`, appending in sprint order. Create it
   with the single header line `# Audit Anchors — Archive` if absent. The archive
   is a write-only sink: no rendered schema region, no validator, no budget.
3. **Verify no-loss:** live entry count + archive entry count MUST equal the
   pre-prune total. A mismatch is a HARD_BLOCK — restore from git, do not commit.

If the file holds 3 entries or fewer, there is nothing to move; that is a pass,
not a skipped step.

### 5c. Pre-Commit Validation Gate

Before committing retro artifacts, run all four checks in order.
Failure on any check blocks the Step 6 commit. **This gate is the only
completeness check retro performs** — the scripts below read the gate log,
the housekeeping envelope, the transcript shape and the provenance block, so
a second hand-run checklist at Step 6a would restate what already blocks the
commit.

**Gate type for validation loading (Rule 21 / Lever 2).** This is the
`retro` gate. When running gate validation (`gate-validation.md`) at
sprint close, declare it `run gate validation [retro]` so the loader
loads the retro slice (universal core + Checks 8, 9, 17,
core-layer-immutability).

1. **Rule file audit commit.** If the rule file audit (Step 4)
   produced file changes, commit them NOW as a separate commit:
   `docs(rules): rule file audit (retro) — strip narrative, harden weak rules`.
   If the audit was clean, skip.

2. **Provenance block verification.** Run
   `scripts/ai-dlc/validate-provenance-block.sh` — it owns the block's shape and
   is also its own CI step. MUST exit 0. **Never invent a `tool_use_id`:**
   if it is not accessible in the conversation (common after compact),
   write `tool_use_id: NOT_ACCESSIBLE`. A fabricated id is a forged block.

3. **Mandatory rules validation.** Run:
   `scripts/ai-dlc/validate-mandatory-rules.sh <N>` (where N is the sprint
   number). It runs `validate-retro-evidence.sh` (Check 1) and inline
   Checks 3/5/6; Checks 2 (`validate-cycle-commits.sh`) and 4
   (`validate-retro-prereq.sh`) are consumer-provided and SKIP when their
   sibling script is absent from core. Check 3 reads the envelope you closed
   in the Close-Out Sweep above via `sprint-status.sh close`.
   MUST exit 0. If it fails, fix the issues before proceeding to Step 6.

4. **Audit-anchor schema validation.** Run
   `scripts/ai-dlc/validate-audit-anchors.sh _bmad-output/audit-anchors.md`. It
   fails closed if the Step-5b header drifted from the canonical schema
   (`.claude/schemas/audit-anchors.json`) or the appended entry is malformed.
   MUST exit 0 — a drifted housekeeping schema is the defect this check exists
   to catch, not a clean file.

### 6. Commit, Push, and PR

**6a. Commit all remaining artifacts.**

Completeness is already gated: Step 5c's four checks fail the commit on a
missing gate-log entry, a missing or malformed audit-anchor entry, and a
missing or malformed provenance block. Do not re-verify them by hand here.
(The next-sprint prompt cannot be checked at this point at all — Step 7d
emits it after this commit, after the merge gate.)

Run `git status` to identify any uncommitted files. Stage and commit
everything produced during the sprint that hasn't been committed yet.
This typically includes:

**Implementation artifacts** (if not already committed per-story):
- `_bmad-output/implementation-artifacts/gate-log.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `docs/reviews/*.md` (code review output)
- `docs/escalations/pending.md` (escalation entries)

**Retro artifacts** (produced in steps 3-5 above):
- `docs/retro/s<N>/retro.md` (the retro document)
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
  Skip the 7a merge gate and proceed to 7a-post.
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

**6e. Announce status — NOT completion.**

Present to the user:
- PR URL (if created)
- Sprint summary (stories delivered, gate results)
- Any open escalations that need human review

Then announce:
- **PR created:** "Sprint [N] artifacts committed. Proceeding to merge gate."
- **Direct-to-main:** "Sprint [N] artifacts committed."

The pipeline's only terminal announcement is Step 7d's handoff block.

### 7. Merge and Next-Sprint Handoff

This step closes the loop on the sprint and produces a copy-pasteable
`/ai-dlc` prompt for the next sprint. The prompt is authored here, not
in the next sprint's discovery step, so that retro findings, unfinished
epic scope, and residual risks are still in the lead's working context.

**7a. Merge gate.**

- **If a PR was created in 6d:** Merge it. Do NOT ask for approval.

  Run `gh pr merge <N> --squash --delete-branch` (use the merge strategy the
  repo's PRs normally use; check recent merges with
  `gh pr list --state merged --limit 3 --json number,title,mergedAt` if unsure).

  On failure — branch protection, required review, failing checks, conflicts —
  surface the error verbatim and STOP: do not rotate (7a-post), do not emit the
  next-sprint prompt. Do NOT retry with `--admin`.
- **If no PR was created (direct-to-main in 6c):** Skip the merge and
  proceed to **7a-post** — not straight to 7b. The artifacts are already on
  `main`, so the rotation's precondition is met and it still has to run.

**7a-post. Rotate the two merge-sensitive logs (Rule 25(c)).**

`gate-log.md` and `compaction-log.md` are append-only per-sprint logs that
`validate-artifact-budget.sh` marks `rotate`, whose breach message reads "a
rotation was MISSED". This is the rotation. Without it that message accuses the
operator of skipping a step this file never defined.

**Runs only after the retro PR has merged** (or, on the direct-to-main path,
once the retro artifacts are on `main`). **If 7a stopped on a failed merge, do
NOT rotate** — the logs stay live until the PR is on `main`. The constraint is the
gate log: a consumer may ship a merge-time validator that reads the live
`## Gate Log: Sprint <N>` section with no archive fallback
(`validate-retro-prereq.sh` is the common one; it is consumer-provided
and absent from core). Emptying the live log before that runs turns the section
missing and the merge is denied. Rotating later is safe for every consumer;
rotating earlier is safe only for some.

The other two `rotate` artifacts — `pipeline-continuation-log.md` and
`context-mode-protection-log.md` — rotate in §4b instead, immediately after the
audit that reads them. Two sites, because the two constraints differ: those must
follow their audit, these must follow the merge.

1. Land on the merged state:
   `git fetch origin main && git checkout main && git merge --ff-only origin/main`
2. Confirm no further gate-log writes remain this sprint. Retro appends no gate
   entry; deploy-validate's was the last write.
3. Archive the WHOLE live log verbatim:

       mkdir -p _bmad-output/implementation-artifacts/s<N>
       git mv _bmad-output/implementation-artifacts/gate-log.md \
              _bmad-output/implementation-artifacts/s<N>/gate-log-archive.md

   If it holds more than this sprint — a missed prior rotation — archive all of
   it under the sprint you are closing and **state the span in the archive's
   first line** (`<!-- covers s<first>..s<N> -->`). The span does NOT go in the
   filename: a basename carrying a sprint token is what forces a reader to
   search, and there is exactly one `gate-log-archive.md` per sprint directory
   so nothing needs disambiguating.
4. Recreate the live log with only the header line `# Gate Log` and a trailing
   newline. No retained entries: no step reads a prior sprint's gate entries,
   counters carry forward in the retro doc, and the cluster audit is git-derived.
5. **Rotate `compaction-log.md` the same way, IF IT EXISTS.** Most sprints never
   compact and the file is absent — that absence is a pass, not a missed
   rotation; record "no compactions this sprint" and skip to 6. Otherwise
   `git mv` it to `implementation-artifacts/s<N>/compaction-log-archive.md` and
   recreate it empty; the
   `PostCompact` hook re-seeds its header on the next write. Confirm §4a's
   artifact-size audit already read it first — its `recovery_injected: no`
   entries must reach the retro doc, because after rotation the live log no
   longer carries them.
6. **Verify no-loss per file:** each archive's byte count MUST equal that file's
   pre-rotation live byte count, and each new live log MUST contain only its
   header. A mismatch is a HARD_BLOCK — do not commit; restore from git and
   investigate.
7. Commit to `main`:
   `chore(s<N>): rotate gate-log and compaction-log post-retro-merge`.
   The commit touches only those files.

**7b. Assemble next-sprint inputs.**

Issued AFTER the 7a merge (no dispatch before Step 5 can cover post-merge
inputs, §2 blocker 2). Dispatch an `analyst` —
**Dispatch C** — to gather all six input classes below (including the
relatedness analysis in input 6) and write the structured bundle to
`_bmad-output/retro-artifacts/s<N>/next-inputs.md`. The lead derives
the theme (7c) and authors the paste-able prompt (7d) from that bundle
**plus its own retained retro findings** — the Step-3 improvements and
Step-4 dispositions stay resident because the lead decided them; only the
raw file reads move to the analyst.

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
4. **Unexercised gates.** Any CI gate declared in `docs/retro/s<N>/retro.md`
   (this sprint's retro) that has not yet run green on a PR — these must
   be exercised in the exercise window or the next retro fails (see
   "Empirical gate validation" above).
5. **Retro improvements with sprint-N+1 follow-ups.** Any action items
   in `docs/retro/s<N>/retro.md` tagged for the next sprint (e.g.,
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
