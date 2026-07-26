---
story_id: story-999-1
acceptance_criteria: 2
---
## Acceptance Criteria

- **AC1 (UNIVERSAL, live_ops).** Exhaustive reference search across the CDK
  source, the TOML template, and the SSM parameters; confirm zero references
  remain.
- **AC2 (EXISTENTIAL, unit).** The resolver returns `None` when the upstream
  read fails, asserted against a fixture that injects the failure.
