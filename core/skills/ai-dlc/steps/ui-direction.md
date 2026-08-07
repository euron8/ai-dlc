---
name: ui-direction
description: Generate UI mockups and present direction (non-blocking)
nextStepFile: ./implementation.md
---
<!-- STEP_LOADED_TOKEN: ui-direction -->

# UI Direction (Phase 2g)

**Purpose:** Generate visual specs for new UI surfaces. Present direction
to the human but continue working — this is NOT a blocking gate.

## EXECUTION SEQUENCE

### 0. Design dispatch (Rule 28)

UI mockup generation, copy, CSS-class specification, and the accessibility /
device review are design production, not orchestration/routing/gate — so per
Rule 28 they are delegated. Spawn a `ux` subagent (Agent tool, bound to
`.claude/team-roles/ux.md` per Rule 19 — `model` + role-contract Read line)
scoped to sections 1, 2, and 4: it generates the ASCII wireframes and copy
for each new UI surface, confirms each introduced CSS class against the
stylesheet, runs the accessibility/device check, writes the result to
`_bmad-output/planning-artifacts/s<N>/ui-mockups.md`, and returns only
`{artifact_path, summary, decisions}`. The lead resumes at section 3
(present) and section 5 (proceed). **Sections 3 and 5 stay inline** — reading
the artifact, presenting it non-blocking to the human, and routing to
implementation are lead actions. An absent artifact at the returned path is
non-delivery; the lead re-dispatches (Rule 24 delivery discipline).

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

Write mockups to `_bmad-output/planning-artifacts/s<N>/ui-mockups.md`
for reference during implementation and production validation.

### 5. Proceed (Do Not Wait)

**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/implementation.md`
