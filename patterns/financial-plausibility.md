# Pattern: Financial/Computation Plausibility Validation

**Category:** Data integrity verification
**Gate check:** #6 (Production integrity tests)
**Severity:** Critical — causes incorrect data display when violated

## What it does

For any computed value displayed to users, a live test independently
recomputes the expected value from source inputs and asserts it matches
the API response. No mocking — real endpoint, real data, real math.

## When to use

Install this pattern when your project computes derived values (financial
calculations, metrics, aggregations, scores) and displays them to users.
Applies to any domain where computation correctness matters — finance,
analytics, monitoring, reporting.

## Configuration

Add to your project's `docs/coding-conventions.md`:

```markdown
### Computation Plausibility Validation

Stories that introduce or modify computed values ({computation_examples})
must include a live test that:
1. Fetches the API response with computed values
2. Independently recomputes the expected value from raw inputs in the
   same response
3. Asserts they match within acceptable tolerance ({tolerance})

**Evidence required:** Run `{smoke_test_command}` and log output in
the story file under "Computation Plausibility". Unit tests with mocks
are not sufficient — they mirror the code's assumptions.
```

## Template variables

- `{computation_examples}`: Domain-specific examples.
  Finance: "APR, P&L, fees, IL, spread, break-even"
  Analytics: "conversion rates, aggregation totals, percentiles"
- `{tolerance}`: Acceptable difference threshold.
  Finance: "0.01% for ratios, $0.01 for currency"
- `{smoke_test_command}`: Command to run live tests.
  Example: `python3 -m pytest server/test_live_smoke.py -v`

## Origin

Graph project Sprint 45 — APR formula was missing `/ pool_days_active`,
showing 3,179% instead of 99%. A five-line test verifying the math
independently would have caught it mechanically.
