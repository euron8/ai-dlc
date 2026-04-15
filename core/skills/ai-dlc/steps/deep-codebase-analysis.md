---
name: deep-codebase-analysis
description: Brownfield B / Analysis-only — comprehensive reverse-engineering of entire codebase
nextStepFile_build: ./discovery.md
nextStepFile_analysis_only: STOP
---

# Deep Codebase Analysis (Brownfield B / Analysis-Only)

**Purpose:** The codebase exists with little or no documentation. Produce
a comprehensive reverse-engineering analysis before planning new work.

## EXECUTION SEQUENCE

### 1. Structure and Stack

Walk every directory and file in the project:
- Document the full project structure, technology stack, frameworks, build
  system, dependencies, and configuration
- Document all environment variables, feature flags, and configuration
  that affects runtime behavior

### 2. Architecture (AS-IS)

- Map every component, service, module, and their boundaries
- Document all data models, database schemas, and data flows
- Document all API contracts (internal and external), integration points,
  and third-party dependencies
- Document all authentication, authorization, and security mechanisms
- Identify architectural patterns in use and any deviations

### 3. Feature Inventory

- Enumerate every user-facing feature and its implementation status
  (complete, partial, broken, stubbed, dead code)
- For each feature, trace the full request path from entry point to data
  store and back

### 4. Quality and Debt

- Catalog all tests. Map coverage by component and feature
- Identify tech debt: deprecated patterns, TODO/FIXME/HACK comments,
  known issues, inconsistent patterns, dead code
- Identify performance concerns: N+1 queries, missing indexes, unbounded
  loops, missing caching, large payloads
- Identify security concerns: hardcoded secrets, missing input validation,
  exposed endpoints, dependency vulnerabilities

### 5. Write Analysis

Write the complete analysis to:
`_bmad-output/planning-artifacts/codebase-analysis.md`

The file MUST be a standalone reference — readable in full without
looking at the code.

### 6. Route

Check `pipeline_variant` from the router:

- If `analysis-only`: Present the analysis to the user. Announce
  "Analysis complete. No implementation pipeline was requested." **STOP.**
- If `brownfield-b`: Run gate validation (`gate-validation.md`), then
  **READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/discovery.md`
