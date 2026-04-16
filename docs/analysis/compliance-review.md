# AI/DLC Workflow Compliance Review

**Date:** 2026-04-16
**Scope:** Full read of every step file (`core/skills/ai-dlc/steps/*.md`),
both templates (`templates/CLAUDE.md.template`, `templates/QUICKSTART.md.template`,
`templates/coding-conventions.md.template`), all team role files
(`core/team-roles/*.md`), and `core/skills/ai-dlc/SKILL.md`. Review is
conducted from the distribution repo perspective: `core/` is the source,
`templates/` are installed to consumer projects by `scripts/install.sh`.
Runtime paths using `{project-root}` are Claude Code variables resolved
in the installed consumer project — not broken placeholders.

---

## Repository Architecture

Distribution repo. `scripts/install.sh` copies `core/skills/ai-dlc/` →
`.claude/skills/ai-dlc/`, `core/team-roles/` → `.claude/team-roles/`, and
`templates/*.template` → project root files. The setup wizard (`/ai-dlc-setup`)
then replaces template variables (`{deploy_command}`, model strings,
ownership paths, etc.) in the installed files. `{project-root}` is a
Claude Code runtime variable, not a template variable — it is not replaced
by the wizard and resolves at execution time.

---

## Executive Summary

All findings from the 2026-03-23 review are resolved. This review found
**8 findings** across a full read of all 18 step files, 3 templates, and
3 team role files:

- **2 important** (QUICKSTART.md.template outdated guidance that bypasses
  the Rule 10 snapshot resume mechanism)
- **3 minor** (one wrong check count, one ambiguous gate waiver, one stale
  cross-reference in dev.md)
- **3 informational** (dual rule numbering system, unresolved model
  placeholders in implementation.md, and the commit-before-gate pattern
  in sprint-review-next.md)

The step file pipeline itself is in good shape. The most operationally
relevant findings are in QUICKSTART.md.template, which was not updated
when Rule 10 added the snapshot-based resume protocol.

---

## Resolution Status of 2026-03-23 Findings

| ID | Finding | Status |
|----|---------|--------|
| C1/C6 | Retro "separate session" language in CLAUDE.md and deploy-validate.md | RESOLVED |
| C2 | CLAUDE.md gate protocol simplified vs. gate-validation.md | RESOLVED — template defers to step files as authoritative |
| C3 | CLAUDE.md deployment section duplicates step files | RESOLVED — template defers to step files |
| C4 | Phase table in CLAUDE.md may diverge | RESOLVED — table includes explicit note that step files govern |
| C5 | Rule numbering overlap SKILL.md vs CLAUDE.md | PARTIALLY RESOLVED — step files consistently use "Autonomy Rule N" for CLAUDE.md rules. Dual numbering persists as an ongoing cognitive overhead (see INFO-1) |
| A1 | Branch strategy executes after READ AND FOLLOW in route.md | RESOLVED — Branch Strategy is Step 5, Compose Pipeline is Step 6 |
| A2 | Missing Advanced Elicitation in architecture.md, stories-test-strategy.md, sprint-review-next.md | RESOLVED — all three include full three-sub-skill cycle |
| A3 | doc-repair-backfill.md missing continuous flow directive | RESOLVED |
| A4 | bug-investigation.md frontmatter misleads routing | RESOLVED — `nextStepFile: conditional (see Step 6)` |
| Q1 | sprint-execute missing from QUICKSTART.md decision tree | RESOLVED — present in QUICKSTART.md.template |
| Q2 | All QUICKSTART.md variant sequences missing retro | RESOLVED |
| Q3 | carry-over sequence wrong in QUICKSTART.md | RESOLVED |
| Q4 | "One human checkpoint" claim incomplete | PARTIALLY RESOLVED — retro added, but ambiguity resolution still missing (see FIND-1) |
| Q5 | Phase Reference missing sprint-review-next and retro commit detail | RESOLVED |

---

## Current Findings

### FIND-1: QUICKSTART.md.template "Two pause points" — should be three (IMPORTANT)

**QUICKSTART.md.template (lines 54–58):**
> "Two pause points. The Production Validation Checkpoint at the end of
> deployment stops and waits for human input. The retro commentary prompt
> (after the retrospective) gives the human a chance to comment before the
> sprint closes. These are the only two points where the pipeline pauses
> for human input."

**SKILL.md Rule 7:**
> "There are exactly THREE points where you stop and wait for human input:
> (a) Ambiguity resolution (Rule 4) — including the three-option prompt
> when handoff is requested at an unsafe seam
> (b) Production Validation Checkpoint (Rule 6)
> (c) Retro commentary prompt"

**Impact:** A user reading QUICKSTART will not know ambiguity resolution
is a pipeline pause point. When the pipeline stops to ask a clarifying
question, the user may be confused about whether something broke. This was
flagged as Q4 in the 2026-03-23 review — retro was added then, but
ambiguity resolution was not.

**Fix:** Update the claim to "three" and add: "(a) Ambiguity resolution —
when the router or any pipeline step detects genuine ambiguity, it stops
to ask one clarifying question before proceeding."

---

### FIND-2: QUICKSTART.md.template "Pipeline interruption" gotcha bypasses snapshot resume (IMPORTANT)

**QUICKSTART.md.template (lines 567–571):**
> "**Pipeline interruption.** If the pipeline is interrupted (crash,
> context exhaustion, manual stop), artifacts on disk represent the last
> completed step. Re-invoke `/ai-dlc` and describe where you left off;
> the router reads project state and resumes."

**route.md Step 0 resume detection:**
> "If YES and the user input contains a resume signal — begins with
> 'Resuming an ai-dlc sprint' OR explicitly references 'pipeline snapshot'
> — this is a resume."
> "If the snapshot exists but user input does NOT indicate a resume ...
> continue to Step 1. Step 6 will detect the stale snapshot and **archive
> it** before creating a new one."

**SKILL.md Rule 10:** Defines a living pipeline snapshot at
`_bmad-output/pipeline-snapshot.md`, updated at every gate passage
(gate-validation.md Check 14). On interruption, the correct procedure
is to use the formal resume prompt beginning with "Resuming an ai-dlc
sprint from handoff checkpoint."

**Impact:** A user following QUICKSTART's guidance re-invokes `/ai-dlc`
with a plain description of where they left off. route.md Step 0 does
not detect this as a resume. Step 6 then archives the existing snapshot
and creates a new one. The pipeline restarts from scratch, losing the
carefully maintained state. This is the exact failure mode the snapshot
mechanism was designed to prevent.

**Fix:** Replace the gotcha with: "**Pipeline interruption.** If the
pipeline is interrupted, use the resume prompt from SKILL.md Rule 10.
In a new conversation, paste: 'Resuming an ai-dlc sprint from handoff
checkpoint. Pipeline snapshot: `_bmad-output/pipeline-snapshot.md`.' Do
NOT re-invoke `/ai-dlc` with a plain description — the router treats any
input that does not begin with the resume signal as a fresh pipeline run
and archives the existing snapshot."

---

### FIND-3: QUICKSTART.md.template "Context Window Guide" predates Rule 10 (IMPORTANT)

**QUICKSTART.md.template (lines 316–348):**
Describes context management with no mention of the pipeline snapshot,
the 40%/50% context reminders, or the formal handoff/resume mechanism.
Key passage:
> "**If you hit context limits:** ... Start a new conversation with
> `/ai-dlc` and describe where you left off; the router will detect
> existing artifacts and resume from the appropriate point."

**SKILL.md Rule 10:** Defines pipeline snapshot, 40%/50% reminders,
and the formal handoff procedure. The "describe where you left off"
approach is the pre-Rule-10 fallback; it produces an unreliable resume
(same failure mode as FIND-2).

**Impact:** Users relying on QUICKSTART for context management guidance
will get degraded recovery behavior and won't know the snapshot mechanism
exists.

**Fix:** Rewrite the Context Window Guide to describe: (1) the pipeline
snapshot as the primary state vehicle, (2) the 40%/50% non-blocking
reminders the lead outputs, (3) the formal resume procedure (use the
resume prompt template). Keep a fallback sentence for edge cases where
the snapshot itself is corrupted.

---

### FIND-4: CLAUDE.md.template gate check count is off by one (MINOR)

**CLAUDE.md.template (line 275):**
> "The full gate protocol is defined in `gate-validation.md` (13 checks
> with evidence requirements)."

**gate-validation.md:** Contains 14 numbered checks (1 through 14).

**Impact:** Low — the template correctly states that agents MUST follow
gate-validation.md, not the summary. The count is informational only.
But an agent or user auditing the gate will notice the mismatch and
may question whether they're reading the right version.

**Fix:** Update "13 checks" to "14 checks."

---

### FIND-5: implementation.md model placeholders — unclear if setup wizard resolves them (MINOR)

**implementation.md (lines 25–33):**
```
- **dev** from `dev.md` — model: {dev_model}.
  <!-- {dev_model}: The model used for dev teammates (e.g., claude-sonnet-4-6) -->
- **code-reviewer** from `code-reviewer.md` — model: {reviewer_model}.
  <!-- {reviewer_model}: The model used for code review (e.g., claude-opus-4-6) -->
- **qa** from `qa.md` — model: {qa_model}.
  <!-- {qa_model}: The model used for QA (e.g., claude-sonnet-4-6) -->
```

The setup wizard updates role files and CLAUDE.md with actual model
strings. It is not confirmed from the SKILL.md description whether it
also updates step files like implementation.md. If it does not, an agent
executing this step will see "model: {dev_model}" as a literal string
and may be confused about which model to use when spawning teammates.

**Mitigating factor:** The role files themselves contain the `/model`
directive that teammates run on spawn. The lead can infer the correct
model from the role files even if the step text is unresolved.

**Fix:** Either confirm and document that `/ai-dlc-setup` replaces these
variables in implementation.md, or replace the step text with "spawn
using the model defined in their role file" and remove the `{model}`
placeholder from the prose.

---

### FIND-6: codebase-inventory.md Step 4 — informal gate waiver is ambiguous (MINOR)

**codebase-inventory.md Step 4:**
> "Run the gate validation protocol (`gate-validation.md`). For this
> step, the validation cycle requirement is waived (this is analysis,
> not a planning artifact). **Check only for HARD_BLOCKs and log the gate.**"

All other steps with a gate call say "Run gate validation
(`gate-validation.md`)" and let gate-validation.md's own scoping rules
(e.g., "Skip this check for planning phase gates") handle what applies.
codebase-inventory.md's phrasing instructs the agent to informally check
"only for HARD_BLOCKs" rather than running the protocol and letting
scoped checks self-select.

**Impact:** An agent executing this step may do an informal mental check
("no HARD_BLOCKs, gate logged") without running gate-validation.md's
Check 14 (snapshot update) or Check 12 (gate log entry). The pipeline
snapshot could go unstale for this gate passage.

**Fix:** Change to "Run gate validation (`gate-validation.md`). Note:
the validation cycle sub-skill checks (Check 1) are waived for this
analysis step. All other applicable checks run normally." This delegates
scoping to gate-validation.md's own logic instead of overriding it.

---

### INFO-1: Dual rule numbering — SKILL.md rules vs. Autonomy Rules (INFORMATIONAL)

**SKILL.md:** Defines Critical Rules numbered 1–10.
**CLAUDE.md.template:** Defines Autonomy Rules numbered 1–11.

The concepts overlap but the numbering differs:

| Concept | SKILL.md | CLAUDE.md (Autonomy) |
|---------|----------|----------------------|
| Walk through everything / apply fixes | Rule 2 (implied) | Rule 1, 2 |
| Full validation cycle | Rule 3 | Rule 3 |
| Seek clarity when ambiguous | Rule 4 | Rule 10 |
| Requirements locked | Rule 5 | Rule 8 |
| Production validation checkpoint | Rule 6 | (described in workflow section) |
| Never stall pipeline | Rule 7 | Rule 1 + overview |
| Every step in full | Rule 8 | Rule 8 (different meaning here) |
| Follow routing | Rule 9 | Rule 9 |
| Handoff + snapshot | Rule 10 | Rule 10 (seek clarity in CLAUDE.md!) |

Step files use "Autonomy Rule N" for CLAUDE.md references, which
distinguishes them from SKILL.md rule numbers. This is workable but
requires an agent to know which document to consult for each namespace.
An agent reading "Autonomy Rule 10" looks in CLAUDE.md and finds "Seek
clarity when ambiguous." An agent reading SKILL.md Rule 10 finds the
handoff protocol.

**No immediate fix required.** The "Autonomy Rule" qualifier is
sufficient disambiguation. Flag for consideration if a future refactor
consolidates the two rule sets.

---

### INFO-2: sprint-review-next.md — commit precedes gate validation (INFORMATIONAL)

**sprint-review-next.md:**
- Step 4: Commit Updated Stories
- Step 5: Gate Validation and Proceed

Stories are committed before the gate runs. If the gate finds an issue
requiring story changes, those changes require a subsequent commit.

**Context:** This pattern is intentional — stories were just validated
through the full three-sub-skill cycle in Step 3, so gate failures are
unlikely. The commit preserves work before the gate announces passage.
The same pattern appears in the retro step (commit, then STOP).

**No fix required.** Documenting for awareness.

---

### INFO-3: dev.md Responsibilities — stale cross-reference to CLAUDE.md for conventions (INFORMATIONAL)

**dev.md (line 35):**
> "Follow the coding conventions defined in CLAUDE.md."

**CLAUDE.md.template (line 527–528):**
> "Coding Conventions: Extracted to `docs/coding-conventions.md`. Agents
> performing implementation ... must read that file."

**dev.md Context Loading (line 77):** Correctly lists
`docs/coding-conventions.md` as the first file to read.

The Responsibilities section points to CLAUDE.md, the Context Loading
section correctly points to the extracted conventions file. The two
sections are inconsistent within dev.md.

**Impact:** Low — an agent following Context Loading (which is more
specific and action-oriented) will load the correct file. The stale
cross-reference in Responsibilities is unlikely to cause incorrect behavior.

**Fix:** Update dev.md line 35 to "Follow the coding conventions in
`docs/coding-conventions.md`."

---

## Full File-by-File Status

### SKILL.md

| Item | Status | Notes |
|------|--------|-------|
| Rule 1: Read CLAUDE.md first | OK | CLAUDE.md installed from template |
| Rule 2: Single conversation + handoff | OK | |
| Rule 3: Autonomous gates — references CLAUDE.md | OK | CLAUDE.md.template has the protocol |
| Rule 4: Seek clarity + preamble requirement | OK | Anti-pattern callout present |
| Rule 5: Requirements locked — references CLAUDE.md Rule 8 | OK | CLAUDE.md.template Rule 8 is correct |
| Rule 6: Production validation references CLAUDE.md Post-Gate section | OK | Section present in CLAUDE.md.template |
| Rule 7: Three pause points | OK | Lists all three; no "separate session" language |
| Rule 8: Every step completed in full | OK | |
| Rule 9: Follow routing | OK | |
| Rule 10: Handoff + snapshot | OK | Complete; consistent with gate-validation.md Check 14 |
| INITIALIZATION READ AND FOLLOW path | OK | Correct post-install path |

### route.md

| Item | Status | Notes |
|------|--------|-------|
| Step 0: Resume check | OK | Snapshot-aware; archives stale snapshot correctly |
| Step 1: Read CLAUDE.md | OK | |
| Step 2: Signal classification | OK | Covers all nine variants |
| Step 3: Decision tree | OK | Matches QUICKSTART.md.template variant table |
| Step 4: Ambiguity check ("Autonomy Rule 10") | OK | Rule 10 in CLAUDE.md.template = seek clarity; correct reference |
| Step 5: Branch strategy | OK | Correctly ordered before pipeline compose |
| Step 6: Pipeline table and snapshot init | OK | All nine variants listed; snapshot archival logic clear |
| Failure modes | OK | |

### discovery.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Context loading | OK | All brownfield artifact paths listed |
| Step 2: Option check ("Autonomy Rule 8") | OK | Rule 8 = requirements/WHAT; escalation logic correct |
| Step 3: Brainstorm — variant-specific behavior | OK | |
| Step 4: Product brief — variant-specific | OK | Feature/brownfield updates only; no full rewrite |
| Step 4a: LOCKED_REQUIREMENTS extraction | OK | Verbatim quote requirement; sources listed |
| Step 5: Validation cycle | OK | All three sub-skills; continuous flow; source fidelity pass |
| Step 6: Gate and proceed | OK | |

### research-requirements.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Research — three sub-skills back-to-back | OK | Continuous flow directive present |
| Step 2: PRD creation — variant-specific | OK | Feature/brownfield update only |
| Step 2a: Propagate locked requirements | OK | "User-input only" rule for new locked reqs clear |
| Step 3: PRD validation | OK | |
| Step 4: Validation cycle | OK | All three sub-skills; continuous flow; source fidelity pass |
| Step 5: Gate and proceed | OK | |

### architecture.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Context loading | OK | |
| Step 2: Variant-specific architecture creation/update | OK | |
| Step 3: Solutioning gate | OK | |
| Step 4: Validation cycle | OK | All three sub-skills including Advanced Elicitation (was MISSING 2026-03-23) |
| Step 5: Gate and proceed | OK | |

### stories-test-strategy.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Implementation readiness | OK | |
| Step 2: Epics and stories — variant-specific | OK | |
| Step 2a: Propagate locked requirements | OK | |
| Step 3: Sprint planning — multi-sprint check ("Rule 9") | OK | Rule 9 in CLAUDE.md.template = multi-sprint phasing |
| Step 4: Story validation cycle | OK | All three sub-skills including Advanced Elicitation (was MISSING 2026-03-23); source fidelity pass |
| Step 5: Test strategy — back-to-back directive | OK | |
| Step 6: Commit planning artifacts | OK | Conventional commit message; scope limited to planning |
| Step 7: UI detection and routing | OK | Gate runs before both branches |

### ui-direction.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Generate mockups | OK | |
| Step 2: Accessibility check | OK | Customizable via HTML comment |
| Step 3: Present direction — non-blocking statement | OK | |
| Step 4: Document mockups | OK | |
| Step 5: Proceed without gate | OK | Gate already ran in stories-test-strategy.md Step 7 before routing here; no new planning artifacts created |

### implementation.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Context loading | OK | |
| Step 2: Model template variables | **FIND-5** | `{dev_model}`, `{reviewer_model}`, `{qa_model}` — unclear if setup wizard resolves in step files |
| Step 3: Three-gate task dependency chain | OK | code-review → QA → story validation chain explicit |
| Step 4: Self-validate task list | OK | Gate log reference present |
| Step 5: Evidence requirements for dev | OK | Scope verification, rename, smoke test, schema introspection all documented; gate check references correct |
| Step 6: Orchestrate | OK | |
| Step 7: All gates passed — route to sprint-review | OK | Intentional: per-story three-gate cycle serves as implementation gate; sprint-level gate runs in sprint-review |

### sprint-review.md

| Item | Status | Notes |
|------|--------|-------|
| Continuous flow directive | OK | Present at step level before Step 1 |
| Step 1: Sprint-level adversarial review | OK | |
| Step 2: Sprint-level party mode | OK | |
| Step 3: Fix and re-validate | OK | |
| Step 4: Gate and proceed | OK | Phase 4+ checks now active |

### sprint-review-next.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Context loading — reads previous sprint artifacts | OK | |
| Step 2: Story relevance check | OK | Dependencies, cross-sprint conflicts covered |
| Step 3: Validation cycle | OK | All three sub-skills including Advanced Elicitation (was MISSING 2026-03-23) |
| Step 4: Commit updated stories — before gate | **INFO-2** | Commit precedes gate; intentional but noted |
| Step 5: Gate and proceed | OK | |

### deploy-validate.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Pre-deployment check | OK | |
| Step 2: Deploy — `{deploy_command}` placeholder | OK | Template variable; setup wizard replaces in CLAUDE.md; deploy-validate reads from CLAUDE.md |
| Step 3: Smoke tests — `{smoke_test_command}` placeholder | OK | Same as above |
| Step 4: Visual verification — conditional on `is_ui_epic` | OK | |
| Step 5: Production Validation Checkpoint | OK | "Retro will run next" — no "separate session" language (was CONTRADICTING 2026-03-23) |
| Step 6: Wait for human | OK | |
| Step 7: Post-validation routing | OK | Multi-sprint → sprint-review-next.md; single/final → retro.md |

### retro.md

| Item | Status | Notes |
|------|--------|-------|
| Step 1: Context loading | OK | |
| Step 2: Party mode retro — continuous flow directive | OK | |
| Step 3: Write retro document | OK | |
| Step 4: Apply process improvements | OK | Five-layer enforcement model; references CLAUDE.md Rule 11 |
| Step 4: Rule 11 reference | OK | Rule 11 defined in CLAUDE.md.template; present in installed project |
| Step 4: Rule file audit paths | OK | `.claude/skills/ai-dlc/steps/*.md` and `.claude/team-roles/*.md` — correct post-install paths |
| Step 5: Human commentary | OK | Three-option pause point (c) from SKILL.md Rule 7 |
| Step 6: Commit, push, PR | OK | Comprehensive artifact list; gh pr create; fallback if gh not available |

### bug-investigation.md

| Item | Status | Notes |
|------|--------|-------|
| Frontmatter | OK | `nextStepFile: conditional (see Step 6)` (was MISLEADING 2026-03-23) |
| Steps 1–6 | OK | Design flaw vs implementation error routing clear |

### carry-over-evaluation.md

| Item | Status | Notes |
|------|--------|-------|
| Steps 1–2 | OK | |
| Step 3: Party mode only (no full validation cycle) | OK | Intentional — this step evaluates item viability, not artifact content. Full validation runs in the subsequent planning pipeline |
| Steps 4–6 | OK | DEFERRAL_REQUEST mechanism; backlog update |
| Step 7: Gate and proceed to discovery | OK | Carry-over items enter full planning pipeline |

### codebase-inventory.md

| Item | Status | Notes |
|------|--------|-------|
| Steps 1–3: Codebase scan, artifact audit, gap report | OK | |
| Step 4: Partial gate waiver | **FIND-6** | "Check only for HARD_BLOCKs" bypasses gate-validation.md protocol; Check 14 (snapshot update) likely skipped |
| Step 5: Proceed | OK | |

### deep-codebase-analysis.md

| Item | Status | Notes |
|------|--------|-------|
| Steps 1–5 | OK | Comprehensive analysis scope |
| Step 6: Route — analysis-only stops, brownfield-b gates and continues | OK | No gate for analysis-only (no phase transition); intentional |

### doc-reconciliation.md

| Item | Status | Notes |
|------|--------|-------|
| Steps 1–5 | OK | Five classification categories (ACCURATE/STALE/WRONG/MISSING FROM DOCS/MISSING FROM CODE) |
| Step 6: Gate and proceed | OK | |

### doc-repair-backfill.md

| Item | Status | Notes |
|------|--------|-------|
| Steps 1–2 | OK | |
| Step 3: Validation cycle | OK | All three sub-skills; continuous flow directive (was MISSING 2026-03-23) |
| Step 4: Gate and proceed | OK | |

### gate-validation.md

| Item | Status | Notes |
|------|--------|-------|
| Check 1: Validation cycle complete | OK | |
| Check 2: No unresolved HARD_BLOCKs | OK | |
| Check 3: Requirement anchor integrity | OK | Drift detection logic; remediation path |
| Check 4: Template placeholder detection | OK | Grep command specified; hard gate |
| Check 5: Story status consistency | OK | Hard gate |
| Check 6: Production integrity tests | OK | Phase 4+ only; exempt categories listed |
| Check 7: Artifact consistency | OK | |
| Check 8: Deployment evidence | OK | Phase 4+ only |
| Check 9: Visual verification | OK | UI sprints only |
| Check 10: Schema/API field verification | OK | Customization comment present |
| Check 11: Smoke test coverage | OK | Test-type-must-match-change-type rule explicit |
| Check 12: Gate log entry | OK | Format references CLAUDE.md.template; format defined there |
| Check 13: Announce gate passage | OK | Check count in announcement |
| Check 14: Update pipeline snapshot | OK | Sections to refresh specified; SKILL.md Rule 10 reference correct |
| Gate failure protocol | OK | Remediate → re-run → HARD_BLOCK if persists |

### CLAUDE.md.template

| Item | Status | Notes |
|------|--------|-------|
| Autonomy Rules 1–11 | OK | All present; Rule 11 (hard directive style) present |
| Gate protocol summary | OK | Defers to gate-validation.md as authoritative |
| Gate log format example | OK | Inline table with example entries |
| Check count | **FIND-4** | "13 checks" — should be 14 |
| Phase table | OK | Includes note "if this table diverges from a step file, the step file governs" |
| Session model | OK | Describes snapshot, 40%/50% reminders, formal handoff |
| Post-Gate Deployment section | OK | Defers to step files as authoritative for execution sequence |
| Key References section | OK | All paths correct post-install |

### QUICKSTART.md.template

| Item | Status | Notes |
|------|--------|-------|
| Variant decision tree | OK | Matches route.md Step 3 |
| Variant pipeline sequences table | OK | All nine variants; all include retro |
| Phase Reference | OK | All steps listed including sprint-review-next |
| Key design principles — pause points | **FIND-1** | "Two pause points" — should be three |
| Context Window Guide | **FIND-3** | Predates Rule 10; no mention of snapshot, 40%/50% reminders, or formal resume |
| Key Gotchas — pipeline interruption | **FIND-2** | Re-invoke guidance bypasses snapshot resume detection |
| Model strings table | OK | Template variables; setup wizard replaces |
| How to Modify section | OK | Consistent with step file conventions |

### coding-conventions.md.template

| Item | Status | Notes |
|------|--------|-------|
| General development rules | OK | |
| Production Integrity Tests section | OK | Consistent with gate-validation.md Check 6 and code-reviewer.md mandatory severity |
| Smoke Test Maintenance section | OK | Test-type-must-match rule; consistent with gate-validation.md Check 11 |
| API/Schema/Fixtures section | OK | |
| Story Spec Quality section | OK | 7-AC limit; source requirements verbatim quote requirement |
| Sprint Process section | OK | |
| Code Review and Validation section | OK | Suggestion-level findings not carried over |
| Template variables | OK | `{project_*}`, `{impact_classification_table}`, `{high_cost_action_gates}` — appropriate for distribution |

### core/team-roles/dev.md

| Item | Status | Notes |
|------|--------|-------|
| Model + effort directives | OK | Template variables; setup wizard replaces |
| Ownership — template variable | OK | |
| Responsibilities — "conventions defined in CLAUDE.md" | **INFO-3** | Should reference `docs/coding-conventions.md`; Context Loading section is correct |
| Context Loading — reads `docs/coding-conventions.md` first | OK | |
| Workflow steps 1–16 | OK | Pre-submission self-check (step 15) comprehensive; consistent with gate checks |
| Escalation protocol references CLAUDE.md Autonomy Rule #4 | OK | CLAUDE.md.template Rule 4 = escalation tiers |

### core/team-roles/code-reviewer.md

| Item | Status | Notes |
|------|--------|-------|
| Model + effort directives | OK | Template variables |
| Review document template | OK | |
| Field verification for API-consuming stories | OK | |
| Mandatory severity classifications | OK | Return type changes = Critical; unit conversion = Important; unverifiable API fields = Important; dead code = Important; missing production integrity tests = Critical; missing/mismatched smoke tests = Important |
| All classifications consistent with gate-validation.md and coding-conventions.md | OK | |
| Escalation protocol references CLAUDE.md Autonomy Rule #4 | OK | |

### core/team-roles/qa.md

| Item | Status | Notes |
|------|--------|-------|
| Model + effort directives | OK | Template variables |
| Validation checklist | OK | Comprehensive; consistent with gate checks |
| Production Integrity Tests hard gate | OK | Consistent with coding-conventions.md and gate-validation.md |
| Smoke test updates hard gate | OK | Test-type-must-match rule; consistent across all three files |
| Escalation protocol references CLAUDE.md Autonomy Rule #4 | OK | |

---

## Summary of Required Fixes

### Important
1. **FIND-2** — Update QUICKSTART.md.template "Pipeline interruption" gotcha.
   Re-invoke guidance archives the snapshot and starts fresh. Replace with
   snapshot resume procedure.
2. **FIND-3** — Rewrite QUICKSTART.md.template "Context Window Guide."
   Predates Rule 10. Add snapshot, 40%/50% reminders, formal resume protocol.

### Minor
3. **FIND-1** — QUICKSTART.md.template: update "Two pause points" to
   "Three" and add ambiguity resolution.
4. **FIND-4** — CLAUDE.md.template line 275: "13 checks" → "14 checks."
5. **FIND-6** — codebase-inventory.md Step 4: replace informal gate waiver
   with standard gate call plus note that Check 1 (validation cycle) is
   waived for analysis steps.

### Informational (no immediate fix required)
6. **FIND-5** — Clarify whether `/ai-dlc-setup` replaces `{dev_model}`,
   `{reviewer_model}`, `{qa_model}` in implementation.md. If not, rewrite
   to reference role files as the model authority.
7. **INFO-1** — Dual rule numbering (SKILL.md vs CLAUDE.md Autonomy Rules)
   persists. Workable with the "Autonomy Rule N" qualifier convention.
8. **INFO-3** — dev.md Responsibilities: update "conventions defined in
   CLAUDE.md" to `docs/coding-conventions.md`. Low impact since Context
   Loading section is correct.
