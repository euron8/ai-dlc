---
name: retro
description: Sprint retrospective — agent runs autonomously, human comments before close
nextStepFile: STOP
---

# Retrospective (Phase 5)

**Purpose:** Review the sprint, extract lessons, apply process
improvements. The agent runs the retro autonomously. The human gets
a chance to comment or ask questions before it closes.

## EXECUTION SEQUENCE

### 1. Context Loading

Read all artifacts from this sprint:
- Sprint stories in `_bmad-output/planning-artifacts/stories/`
- Code reviews in `docs/reviews/`
- Gate log at `_bmad-output/implementation-artifacts/gate-log.md`
- Escalation log at `docs/escalations/pending.md`
- Sprint-status.yaml

### 2. Party Mode Retro

Run `/bmad-party-mode` — bring all agent perspectives (PM, Architect,
Dev, SM, TEA, QA) into the discussion:
- Walk through every story's journey from plan to merge
- What worked well in the pipeline
- What caused friction or rework
- Where requirements drifted (check LOCKED_REQUIREMENTS fidelity)
- Where evidence requirements caught issues vs where they were missed
- Process improvements to propose

### 3. Write Retro Document

Write the retro to `docs/retro/sprint-N.md` with:
- Sprint summary (planned vs delivered, rework cycles, autonomous decisions)
- Agent findings (from party mode)
- Specific, actionable improvements
- Which improvements should update CLAUDE.md, team roles, or pipeline steps

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
advisory, not structural — and advisory rules have repeatedly failed
to prevent the problems they were designed to catch.

**For advisory improvements (best practices, conventions):**
- Apply the change to the relevant file(s)

**For all improvements:**
- Document what was changed and why in the retro doc
- List which files were modified and which enforcement layers were added

### 5. Human Commentary

Present the retro summary and ask:

"Retro complete. Any comments or questions before I close out the sprint?"

Wait for the human's response. If they have commentary:
- Incorporate it into the retro doc
- Apply any additional process changes they request
If they have nothing to add, proceed.

### 6. Commit and Push

Commit all sprint artifacts (retro doc, process improvements, status
updates) and push to origin.

Announce: "Sprint [N] complete. Pipeline finished."

**STOP.**
