---
name: ui-direction
description: Generate UI mockups and present direction (non-blocking)
nextStepFile: ./implementation.md
---

# UI Direction (Phase 2g)

**Purpose:** Generate visual specs for new UI surfaces. Present direction
to the human but continue working — this is NOT a blocking gate.

## EXECUTION SEQUENCE

### 1. Generate Mockups

For each new UI surface in the sprint stories:
1. Generate an ASCII wireframe showing: layout structure, component
   groupings, heading text, all user-facing copy (labels, headings,
   badge text, button labels).
2. List all CSS classes that will be introduced or modified. Confirm each
   class exists in the stylesheet or is being added.
3. Review against the product brief and user personas: does the layout
   reflect how a user thinks? Is the copy clear and actionable?

### 2. Accessibility and Device Check

<!-- Customize this section for your project's target devices and
     accessibility requirements. Examples:
     - Touch-first: if users access via mobile/tablet, verify no
       hover-dependent patterns for critical data display
     - Screen readers: verify ARIA labels and semantic HTML
     - Keyboard navigation: verify tab order and focus management -->

Verify mockups meet the project's accessibility and device requirements.
Use appropriate alternatives for any interaction patterns that would be
inaccessible to the target user base.

### 3. Present Direction (Non-Blocking)

Output the mockups and copy to the conversation. Include:
- ASCII wireframe per surface
- All user-facing copy
- CSS class list
- Any design decisions made and rationale

**State clearly:** "UI direction presented above. Continuing to
implementation. Interrupt at any point if you want to steer the direction."

### 4. Document Mockups

Write mockups to `_bmad-output/planning-artifacts/ui-mockups-sprint-N.md`
for reference during implementation and production validation.

### 5. Proceed (Do Not Wait)

**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/implementation.md`
