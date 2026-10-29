---
story_id: story-320-5
acceptance_criteria: 2
---
## Acceptance Criteria

- **AC1 (UNIVERSAL, unit).** The parser returns exactly 3 rows for the
  pinned 3-row input; assert `len(rows) == 3`.
- **AC2 (EXISTENTIAL, live_ops, probabilistic/passive-monitoring).** The read runs
  in the final 12 hours before the T+7 ceiling and records each kept row id.
