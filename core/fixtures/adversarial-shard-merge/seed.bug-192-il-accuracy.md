# Bug 192: Impermanent Loss Calculation Accuracy

## Source Requirements

> "perform thorough research on how impermanent loss should be calculated. Our implementation is not producing very accurate impermanent loss at all."

## Root Cause Analysis

Three distinct IL computation bug classes identified across the codebase:

### Bug Class A — Rebalancer `il_drag_7d_pct` uses V2 full-range formula

