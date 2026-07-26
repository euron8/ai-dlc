---
story_id: story-999-3
acceptance_criteria: 2
---
## Acceptance Criteria

- **AC1 (UNIVERSAL, unit).** Parametrize over all 7 read fetch names
  (`status, meta_json, pool_json, pool_swap_json, ref_swap_json,
  ref_price_day_json, pool_day_json`); per name assert `payload["degraded"] is
  True` and that the name is in `degraded_fetches`. Plus a 2-simultaneous case
  asserting `set(degraded_fetches)` EXACT-equality, not membership.
- **AC2 (EXISTENTIAL, integration).** One visible degraded indicator renders
  when `payload.degraded == True`, verified in a browser against the pinned
  fixture.
