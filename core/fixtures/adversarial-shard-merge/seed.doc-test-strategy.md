# Sprint 143 Test Strategy

**Sprint:** 143
**Date:** 2026-04-15
**Scope:** Item 338 R6a fix + Items 353/386/387

## Risk Matrix

| Risk | Severity | Test Layer | AC |
|---|---|---|---|
| insideGrowthDirect wrong value / revert uncaught | HIGH | Matchstick | AC4 |
| Sprint 141 guard accidentally removed | HIGH | Code review | AC2 |
| Baseline advance removed (silent double-count) | HIGH | Code review | IC-S143-5 |
| Reindex Phase too small | HIGH | Pre-deploy check | AC8 |
| ACCRUAL_CATCHUP_BLOCK wrong | HIGH | Pre-deploy check | AC6 |
| Violations persist post-fix (residual class) | HIGH | Post-reindex check | AC11 |
| Test still fails after fix (matchstick store) | MEDIUM | AC3 verify step | AC3 |
| Scale-up skipped | MEDIUM | Operational | AC7 |
| il_method smoke still failing | LOW | Smoke suite | AC5 |

## Quality Gates

**Gate 1 (Code Review — opus):**
- insideGrowthDirect implementation per ADR-S143-1
- insideGrowthNow + clampTicksToInitialized: UNCHANGED
- Sprint 141 guard (pool.ts:1695-1752): UNCHANGED
- Baseline advance: PRESENT
- Test skip removal: VERIFIED

**Gate 2 (QA — sonnet):**
- AC4 matchstick output: pass/fail/skip counts
- AC5 il_method expectation: 2 assertions updated
- AC3 skip removal: `grep SPRINT_143_R6A_FIX_SKIP` → no match

**Gate 3 (Story Validation):**
- Check 5b: 143-1 is sole story for Item 338; no cross-validation needed
- AC11 evidence present in dev record

## Adversarial Review of Test Strategy

Test coverage is adequate for the scope. The primary fix validation (matchstick +
invariant check) covers both the unit behavior and the end-to-end production signal.
The only gap is the matchstick store behavior for Sprint 141 guard — mitigated by
the AC3 "verify before and after fix" instruction. No additional test layers needed.
