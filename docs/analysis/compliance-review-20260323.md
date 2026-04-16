# AI/DLC Workflow Compliance Review

**Date:** 2026-03-23
**Scope:** Full review of all workflow step files against CLAUDE.md and
QUICKSTART.md templates for contradictions, ambiguity, and alignment.

---

## Executive Summary

The review found **6 critical contradictions** between CLAUDE.md and
the workflow step files, **4 significant ambiguities** in step files
that could cause the agent to deviate from intended behavior, and
**5 alignment gaps** in QUICKSTART.md where documentation doesn't
match the actual pipeline.

The most impactful finding is that CLAUDE.md describes the retro as a
"separate conversation, initiated by the human" in three places, while
the workflow routes to retro.md inline as the final pipeline step. This
directly contradicts the step file routing and has been observed to
confuse agents about whether to continue or stop.

The second most impactful finding is that CLAUDE.md contains summarized
versions of workflow logic (phase table, gate protocol, deployment
process) that have drifted from the authoritative step files. When an
agent reads CLAUDE.md first (as instructed by SKILL.md Rule 1), it
forms expectations that may conflict with the actual step files.

The third category involves missing validation sub-skills in step files.
CLAUDE.md Rule 3 requires Party Mode → Advanced Elicitation → Adversarial
Review for every planning artifact, but architecture.md,
stories-test-strategy.md, and sprint-review-next.md omit Advanced
Elicitation from their validation cycles.

---

## Critical Contradictions (CLAUDE.md vs. Workflow)

### C1: Retro session model — 3 contradictions

**CLAUDE.md (line 191, phase table):**
`| 5. Retro | sonnet | Party mode -> lessons -> process updates | Human-initiated (separate session) |`

**CLAUDE.md (line 240-241, Session Model):**
"The retro (Phase 5) is a separate conversation, initiated by the human when ready."

**CLAUDE.md (line 25, Continuous flow):**
Lists `(c) the retro commentary prompt` as a pause point — this is
correct for inline retro but contradicts the "separate session" claim above.

**Workflow (deploy-validate.md line 134-135):**
Routes directly to retro.md: `READ AND FOLLOW: {project-root}/.claude/skills/ai-dlc/steps/retro.md`

**Workflow (route.md lines 111-118):**
Every pipeline variant sequence ends with `→ retro`.

**Impact:** Agent may stop after deploy-validate and wait for the user
to initiate a retro in a new session, or it may run the retro inline
and then second-guess whether it should have. The deploy-validate step
itself contributes to the confusion — line 105-106 says "Kick off
/bmad-retrospective when ready" for single sprints, implying user-initiated.

**Fix required:** Update CLAUDE.md to state the retro runs inline.
Remove "separate session" and "human-initiated" language. Fix
deploy-validate.md line 105-106 text.

### C2: Autonomous Gate Protocol simplification

**CLAUDE.md (lines 193-216):**
Describes the Autonomous Gate Protocol with 5 checks.

**Workflow (gate-validation.md):**
Defines 12 checks with detailed evidence requirements.

**Impact:** Agent reads CLAUDE.md first (per SKILL.md Rule 1) and
forms an expectation of a 5-check gate. When gate-validation.md is
loaded later with 12 checks, the agent may treat the additional 7 as
optional or supplementary rather than mandatory.

**Fix required:** CLAUDE.md should reference gate-validation.md as the
authoritative gate protocol rather than providing its own simplified
version. Keep a brief summary but explicitly state "see
gate-validation.md for the full 12-check protocol."

### C3: Post-Gate Deployment duplication

**CLAUDE.md (lines 365-390):**
Describes the post-gate deployment process inline with specific steps
(sprint review, deploy, smoke test, checkpoint).

**Workflow (deploy-validate.md):**
Contains the authoritative deployment process with more detail.

**Impact:** If deploy-validate.md is updated but CLAUDE.md isn't (or
vice versa), the agent receives conflicting deployment instructions.
The deploy-validate step file already includes sprint review routing
via sprint-review.md as a separate step, but CLAUDE.md bundles it into
the post-gate deployment section.

**Fix required:** CLAUDE.md should reference the workflow step files
as authoritative. Keep a brief summary for context but add: "The
authoritative process is defined in the step files
(sprint-review.md → deploy-validate.md → retro.md)."

### C4: Phase table duplicates and may diverge from step routing

**CLAUDE.md (lines 178-191):**
Phase table lists specific activities per phase.

**Workflow step files:**
Each step file defines its own execution sequence.

**Impact:** The phase table can drift from step files. Currently it
doesn't include the planning commit (stories-test-strategy Step 6),
branch strategy (route Step 6), or the commit/push/PR process
(retro Step 6). It also doesn't mention sprint-review-next for
multi-sprint transitions.

**Fix required:** Add a note that the phase table is a summary and
the authoritative execution sequence is in each step file. Add missing
phases or mark as "see step files for complete sequence."

### C5: Rule numbering overlap between SKILL.md and CLAUDE.md

**SKILL.md:** 9 Critical Rules (numbered 1-9).
**CLAUDE.md:** 10 Autonomy Rules (numbered 1-10).

They cover overlapping territory with different numbers:
- SKILL.md Rule 4 = "Seek clarity when ambiguous"
- CLAUDE.md Rule 10 = "Seek clarity when ambiguous"
- SKILL.md Rule 5 = "Requirements are locked" (references CLAUDE.md Rule 8)
- CLAUDE.md Rule 8 = "Requirements define WHAT..."

**Impact:** When a step file says "Rule 8" or "Rule 10," the agent
must determine which file's numbering system is being used. route.md
Step 4 references "Rule 10" (meaning CLAUDE.md Rule 10), while
discovery.md Step 2 references "Autonomy Rule 8" (correctly
specifying CLAUDE.md). Inconsistent referencing creates ambiguity.

**Fix required:** All step file references should use "Autonomy Rule N"
(for CLAUDE.md rules) or "SKILL.md Rule N" (for SKILL.md rules). Never
use bare "Rule N" without specifying the source.

### C6: deploy-validate.md suggests retro is user-initiated

**deploy-validate.md (lines 105-106):**
`[If single sprint: "Sprint complete. Kick off /bmad-retrospective when ready."]`

**Workflow routing (deploy-validate.md lines 134-135):**
Routes directly to retro.md after human validation.

**Impact:** The checkpoint presentation text tells the user to "kick
off" the retro, implying it won't happen automatically. But Step 7
routes to retro.md regardless. The user may think they need to act,
while the agent continues.

**Fix required:** Change the text to indicate the retro will run
next, not that the user needs to initiate it.

---

## Significant Ambiguities in Step Files

### A1: route.md branch strategy ordering

**route.md Step 5:** Compose Pipeline and Begin — ends with
"READ AND FOLLOW" directive to load the first step file.

**route.md Step 6:** Branch Strategy — creates a branch before starting.

**Problem:** Step 6 is listed AFTER Step 5's "READ AND FOLLOW." The
logical execution should be: detect variant (Steps 1-4), create
branch (Step 6), THEN load the first step (Step 5's directive). The
current ordering means the agent might load the first step file before
creating the branch.

**Fix required:** Reorder so branch strategy runs before the
"READ AND FOLLOW" directive.

### A2: Missing Advanced Elicitation in 3 step files

**CLAUDE.md Rule 3:** "Every planning artifact goes through Party Mode
-> Advanced Elicitation -> Adversarial Review (2+ passes)."

**architecture.md Step 4:** Party Mode → Adversarial Review. Missing
Advanced Elicitation.

**stories-test-strategy.md Step 4:** Party Mode → Adversarial Review.
Missing Advanced Elicitation.

**sprint-review-next.md Step 3:** Party Mode → Adversarial Review.
Missing Advanced Elicitation.

**discovery.md and research-requirements.md:** Both correctly include
all three.

**Impact:** Agent may follow the step file (skip elicitation) which
contradicts CLAUDE.md Rule 3. Or it may follow Rule 3 and add
elicitation, but the step file doesn't instruct it to. Either way,
behavior is ambiguous.

**Fix required:** Add Advanced Elicitation to all three step files'
validation cycles, or update CLAUDE.md Rule 3 to specify which
artifacts require full three-step validation vs. two-step.

### A3: doc-repair-backfill.md missing continuous flow directive

**doc-repair-backfill.md Step 3:** Lists validation cycle (party mode,
elicitation, adversarial review) but doesn't include the "Execute all
sub-skills back-to-back without pausing" directive that was added to
discovery.md, research-requirements.md, architecture.md, and
stories-test-strategy.md.

**Impact:** Agent may pause between sub-skills during brownfield-c
doc repair, since the step file doesn't reinforce the continuous flow
requirement.

**Fix required:** Add the continuous flow directive to
doc-repair-backfill.md Step 3.

### A4: bug-investigation.md frontmatter vs. conditional routing

**bug-investigation.md frontmatter:** `nextStepFile: ./implementation.md`

**bug-investigation.md Step 6:** Conditional routing — design flaw goes
to discovery.md, implementation error goes to implementation.md.

**Impact:** If an agent reads frontmatter to determine routing instead
of following the execution sequence, it will always go to
implementation.md even for design flaws.

**Fix required:** Update frontmatter to indicate conditional routing:
`nextStepFile: conditional (see Step 6)`

---

## QUICKSTART.md Alignment Gaps

### Q1: Missing sprint-execute variant

**route.md:** Includes `sprint-execute` variant
(implementation → sprint-review → deploy-validate → retro).

**QUICKSTART.md decision tree (lines 156-182):** Missing sprint-execute.
The first check in route.md is "Is there a planned sprint with stories
ready for implementation?" which is the sprint-execute detection — but
QUICKSTART.md's decision tree starts with "Is this a bug fix?"

**QUICKSTART.md variant table (lines 186-195):** Missing sprint-execute.

**Fix required:** Add sprint-execute to both the decision tree and
variant table.

### Q2: All variant sequences missing retro

**QUICKSTART.md variant sequences (lines 186-195):**
Every sequence ends at `deploy-validate`. None include `→ retro`.

**route.md variant sequences (lines 111-118):**
Every sequence ends with `→ retro`.

**Fix required:** Add `→ retro` to all sequences.

### Q3: carry-over variant sequence wrong

**QUICKSTART.md (line 191):**
`carry-over-evaluation --> stories-test-strategy --> implementation --> sprint-review --> deploy-validate`

**route.md (line 115):**
`carry-over-evaluation → discovery → research-requirements → architecture → stories-test-strategy → [ui-direction] → implementation → sprint-review → deploy-validate → retro`

**carry-over-evaluation.md routing:** Routes to discovery.md, which
chains through the full planning pipeline.

**Impact:** QUICKSTART.md shows carry-over skipping the entire planning
pipeline (discovery, research, architecture) which doesn't match the
actual workflow.

**Fix required:** Update QUICKSTART.md carry-over sequence to match
route.md.

### Q4: "One human checkpoint" claim incomplete

**QUICKSTART.md (line 53):**
"One human checkpoint. The Production Validation Checkpoint at the end
of deployment is the only point where the pipeline stops and waits for
human input."

**Workflow:** The retro commentary prompt (retro.md Step 5) is also a
human input pause point. SKILL.md Rule 7 explicitly lists it as
pause point (c).

**Fix required:** Update to mention both pause points.

### Q5: Phase Reference missing sprint-review-next and retro

**QUICKSTART.md Phase Reference (lines 207-223):**
Lists all step summaries but the retro line reads only:
"Retro (Phase 5): Retrospective + process improvements"

Missing: commit/push/PR creation, which is a significant part of the
retro step. Also missing: sprint-review-next step summary.

**Fix required:** Add sprint-review-next to the phase reference list.
Expand retro description to include commit/push/PR.

---

## Step-by-Step Detailed Review

### SKILL.md

| Item | Status | Notes |
|------|--------|-------|
| Rule 1: Read CLAUDE.md first | OK | Clear directive |
| Rule 2: Single conversation | OK | Aligns with workflow |
| Rule 3: Autonomous gates | OK | Aligns with gate-validation.md |
| Rule 4: Seek clarity | OK | Aligns with CLAUDE.md Rule 10 |
| Rule 5: Requirements locked | OK | References CLAUDE.md Rule 8 |
| Rule 6: Production validation only human checkpoint | **INCOMPLETE** | Missing retro commentary as pause point. Rule 7 correctly lists it but Rule 6 doesn't |
| Rule 7: Never pause between sub-skills | OK | Clear, lists all 3 pause points |
| Rule 8: Every step completed in full | OK | Strong anti-skip directive |
| Rule 9: Follow routing not judgment | OK | Strong anti-skip directive |
| Initialization: READ AND FOLLOW route.md | OK | Clear entry point |

### route.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Read Project State | OK | Comprehensive artifact checks |
| Step 2: Analyze User Input | OK | Clear signal classification |
| Step 3: Route to Pipeline Variant | OK | Decision tree is unambiguous |
| Step 4: Ambiguity Check | **AMBIGUOUS** | References "Rule 10" — should say "Autonomy Rule 10" |
| Step 5: Compose Pipeline | OK | Complete variant table |
| Step 6: Branch Strategy | **MISORDERED** | Should execute before Step 5's READ AND FOLLOW |
| Multi-sprint note | OK | Clear description of sprint-review-next loop |
| Failure modes | OK | Clear fallbacks |

### discovery.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Context Loading | OK | Lists all relevant artifacts |
| Step 2: Option Check | OK | References Autonomy Rule 8 correctly |
| Step 3: Brainstorm | OK | Variant-specific behavior documented |
| Step 4: Product Brief | OK | Variant-specific behavior documented |
| Step 4a: Locked Requirements | OK | Comprehensive extraction instructions |
| Step 5: Validation Cycle | OK | All 3 sub-skills present with continuous flow directive |
| Step 6: Gate and Proceed | OK | Clear routing to research-requirements.md |

### research-requirements.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Research | OK | Continuous flow directive present |
| Step 2: PRD Creation | OK | Variant-specific, preserves locked requirements |
| Step 2a: Propagate Locked Requirements | OK | Clear rule about what qualifies |
| Step 3: PRD Validation | OK | |
| Step 4: Validation Cycle | OK | All 3 sub-skills present with continuous flow directive |
| Step 5: Gate and Proceed | OK | Clear routing to architecture.md |

### architecture.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Context Loading | OK | |
| Step 2: Architecture Creation/Update | OK | Variant-specific behavior |
| Step 3: Solutioning Gate | OK | |
| Step 4: Validation Cycle | **MISSING ELICITATION** | Only Party Mode + Adversarial Review. Rule 3 requires Advanced Elicitation. Continuous flow directive present. |
| Step 5: Gate and Proceed | OK | Clear routing |

### stories-test-strategy.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Implementation Readiness | OK | |
| Step 2: Epics and Stories | OK | Variant-specific behavior |
| Step 2a: Propagate Locked Requirements | OK | |
| Step 3: Sprint Planning | OK | Multi-sprint phasing documented |
| Step 4: Story Validation Cycle | **MISSING ELICITATION** | Only Party Mode + Adversarial Review. Continuous flow directive present. |
| Step 5: Test Strategy | OK | TEA + adversarial review |
| Step 6: Commit Planning Artifacts | OK | Clear artifact list and commit message |
| Step 7: UI Detection and Routing | OK | Clear conditional routing |

### ui-direction.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Generate Mockups | OK | |
| Step 2: Accessibility Check | OK | Customizable via HTML comment |
| Step 3: Present Direction | OK | Non-blocking, clear messaging |
| Step 4: Document Mockups | OK | |
| Step 5: Proceed | OK | Clear routing, no waiting |

### implementation.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Context Loading | OK | |
| Step 2: Create Agent Team | OK | Template variables for model strings |
| Step 3: Create Task List | OK | Three-gate dependency chain |
| Step 4: Self-Validate Task List | OK | |
| Step 5: Begin Implementation | OK | Comprehensive evidence requirements |
| Step 6: Orchestrate | OK | |
| Step 7: All Gates Passed | OK | Clear routing to sprint-review.md |

### sprint-review.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Adversarial Review | OK | |
| Step 2: Party Mode | OK | |
| Step 3: Fix and Re-Validate | OK | |
| Step 4: Gate and Proceed | OK | Clear routing to deploy-validate.md |
| Missing | **NOTE** | No continuous flow directive between Steps 1 and 2. Should have "Execute sub-skills back-to-back." |

### sprint-review-next.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Context Loading | OK | Reads previous sprint artifacts |
| Step 2: Story Relevance Check | OK | Comprehensive checks |
| Step 3: Validation Cycle | **MISSING ELICITATION** | Only Party Mode + Adversarial Review. Continuous flow directive present. |
| Step 4: Commit Updated Stories | OK | |
| Step 5: Gate and Proceed | OK | Clear routing to implementation.md |

### deploy-validate.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Pre-Deployment Check | OK | |
| Step 2: Deploy | OK | Template variable for command |
| Step 3: Smoke Tests | OK | Evidence capture |
| Step 4: Visual Verification | OK | Conditional on is_ui_epic |
| Step 5: Production Validation Checkpoint | **CONTRADICTS RETRO MODEL** | Text says "Kick off /bmad-retrospective when ready" (line 105-106) implying user-initiated retro |
| Step 6: Wait for Human | OK | |
| Step 7: Post-Validation Routing | OK | Multi-sprint routes to sprint-review-next.md. Single/final routes to retro.md. |

### retro.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Context Loading | OK | |
| Step 2: Party Mode Retro | OK | |
| Step 3: Write Retro Document | OK | |
| Step 4: Apply Process Improvements | OK | Five-layer enforcement model |
| Step 5: Human Commentary | OK | Clear pause point |
| Step 6: Commit, Push, and PR | OK | Comprehensive artifact list, PR creation |
| Missing | **NOTE** | No continuous flow directive between Steps 1-4 sub-skill invocations. Step 2 invokes party mode which could pause. |

### bug-investigation.md

| Item | Status | Notes |
|------|--------|-------|
| Frontmatter | **MISLEADING** | Says `nextStepFile: ./implementation.md` but routing is conditional (Step 6 may route to discovery.md) |
| Step 1: Context Loading | OK | |
| Step 2: Investigation | OK | Design flaw vs. implementation error distinction |
| Step 3: Create Fix Story | OK | Source requirements preserved |
| Step 4: Validation | OK | Adversarial review with source fidelity |
| Step 5: Sprint Setup | OK | |
| Step 6: Conditional Routing | OK | Clear branching logic |

### carry-over-evaluation.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Context Loading | OK | |
| Step 2: Item Evaluation | OK | Includes option check for Rule 8 |
| Step 3: Party Mode Evaluation | OK | |
| Step 4: Deferral Handling | OK | DEFERRAL_REQUEST mechanism |
| Step 5: Close Invalid Items | OK | |
| Step 6: Update Backlog | OK | |
| Step 7: Proceed | OK | Routes to discovery.md for full planning |

### codebase-inventory.md (Brownfield A)

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Codebase Scan | OK | |
| Step 2: Artifact Audit | OK | |
| Step 3: Gap Analysis | OK | |
| Step 4: Gate Validation | OK | Validation cycle waived (analysis only) |
| Step 5: Proceed | OK | Routes to discovery.md |

### deep-codebase-analysis.md (Brownfield B / Analysis-Only)

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Structure and Stack | OK | |
| Step 2: Architecture (AS-IS) | OK | |
| Step 3: Feature Inventory | OK | |
| Step 4: Quality and Debt | OK | |
| Step 5: Write Analysis | OK | |
| Step 6: Route | OK | Conditional: analysis-only → STOP, brownfield-b → discovery.md |

### doc-reconciliation.md (Brownfield C)

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Documentation Inventory | OK | |
| Step 2: Codebase Scan | OK | |
| Step 3: Reconciliation | OK | Five-category classification |
| Step 4: Gap Analysis | OK | |
| Step 5: Write Report | OK | |
| Step 6: Gate and Proceed | OK | Routes to doc-repair-backfill.md |

### doc-repair-backfill.md (Brownfield C continuation)

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Repair Existing Docs | OK | |
| Step 2: Backfill Missing Artifacts | OK | |
| Step 3: Validation Cycle | **MISSING CONTINUOUS FLOW** | Lists all 3 sub-skills but doesn't include "Execute back-to-back" directive |
| Step 4: Gate and Proceed | OK | Routes to discovery.md |

### gate-validation.md

| Item | Status | Notes |
|------|--------|-------|
| Check 1: Validation cycle complete | OK | |
| Check 2: No HARD_BLOCKs | OK | |
| Check 3: Requirement anchor integrity | OK | Detailed drift detection |
| Check 4: Template placeholder detection | OK | Hard gate |
| Check 5: Story status consistency | OK | Hard gate |
| Check 6: Production integrity tests | OK | Implementation gates only |
| Check 7: Artifact consistency | OK | |
| Check 8: Deployment evidence | OK | Implementation gates only |
| Check 9: Visual verification | OK | UI sprints only |
| Check 10: Schema/API field verification | OK | Schema-modifying stories only |
| Check 11: Gate log entry | OK | Per-check evidence required |
| Check 12: Announce passage | OK | Check count for verifiability |
| Gate Failure | OK | Remediation protocol clear |

---

## Summary of Required Fixes

### Critical (must fix — causes incorrect agent behavior)
1. **C1/C6:** Remove "separate session" retro language from CLAUDE.md (3 locations) and deploy-validate.md (1 location)
2. **A1:** Reorder route.md so branch strategy (Step 6) executes before the first step's READ AND FOLLOW
3. **A2:** Add Advanced Elicitation to architecture.md, stories-test-strategy.md, and sprint-review-next.md

### Important (should fix — reduces ambiguity)
4. **C2:** CLAUDE.md gate protocol should reference gate-validation.md as authoritative
5. **C3:** CLAUDE.md deployment section should reference step files as authoritative
6. **C4:** Add workflow-authority note to CLAUDE.md phase table
7. **C5:** Standardize rule references across all step files to "Autonomy Rule N"
8. **A3:** Add continuous flow directive to doc-repair-backfill.md and retro.md
9. **A4:** Fix bug-investigation.md frontmatter to indicate conditional routing

### Documentation (alignment)
10. **Q1:** Add sprint-execute to QUICKSTART.md
11. **Q2:** Add retro to all QUICKSTART.md variant sequences
12. **Q3:** Fix carry-over sequence in QUICKSTART.md
13. **Q4:** Update "one human checkpoint" to include retro commentary
14. **Q5:** Add sprint-review-next and expand retro in Phase Reference
15. Add continuous flow directive to sprint-review.md
