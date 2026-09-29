# Sprint 34 Epics — Spread Data Point Semantics and Market Context Rework

**Sprint:** 34
**Date:** 2026-03-16
**Scope:** 26 (Spread Data Point Semantics and Market Context Rework)

---

## Epic 57: Spread Data Point Semantics and Market Context Rework

**Goal:** Rework the spread confidence endpoint and dashboard display from "is my data accurate?" to "is my pool competitive?" — tier-aware thresholds, enriched response fields, narrative dashboard display with color coding.

**Source requirement (carry-over Item 55, verbatim):** "Sprint 33 (Epic 56) shipped three spread data points to the dashboard: 1. Aggregator spread (43 bps): fee + price impact computed from subgraph swap data. 2. Pool spread (6.5 bps): on-chain V4Quoter same-pool price impact only. 3. Market spread (2.8 bps): Uniswap Trading API BEST_PRICE routing across all pools. These numbers are displayed but their meaning and actionability need deeper exploration."

**n8's stated questions (from Item 55):**
1. What does the delta between these three values actually tell the operator?
2. How should calibration thresholds be set?
3. Are the current display labels and formatting intuitive?
4. Which data points are most useful for decision-making?
5. Should the presentation change based on context?

**Architecture reference:** docs/architecture.md addendum "Spread Data Point Semantics and Market Context Rework (Feature Scope 26, 2026-03-16)"

**PRD references:** US-83, US-84. NFRs 132-135.

### Stories

| ID | Title | Layer | Depends On | Effort | PRD |
|----|-------|-------|------------|--------|-----|
| 57-1 | Aggregator spread market context rework | Aggregator | US-81 (delivered Sprint 33, Story 56-1) | Medium | US-83 |
| 57-2 | Dashboard narrative display rework | Dashboard | 57-1 | Small-Medium | US-84 |

### Dependency Graph

```
US-81 (aggregator spread confidence endpoint, Sprint 33, DONE)
  ├── US-82 (dashboard spread confidence badge, Sprint 33, DONE)
  └── 57-1 (aggregator spread market context rework)
        └── 57-2 (dashboard narrative display rework)
```

Sequential: 57-2 depends on 57-1 for the reworked API response shape it consumes.

---

### Parallel Execution Windows

**Window 1 (immediate):** 57-1
- Aggregator endpoint rework

**Window 2 (after 57-1):** 57-2
- Dashboard display rework

### Reindex Plan

**No reindex required.** Both stories are aggregator + dashboard only. No subgraph changes. No new env vars.

---

### Changelog

- 2026-03-16: Initial epic and story breakdown created. 1 epic, 2 stories across 2 layers (aggregator, dashboard). Sequential dependency: 57-1 → 57-2. No subgraph changes, no reindex.
