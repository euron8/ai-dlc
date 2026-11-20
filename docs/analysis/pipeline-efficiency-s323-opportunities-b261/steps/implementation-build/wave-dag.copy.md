# Sprint 323 — Story Dependency DAG + Wave Plan

Written before the first dev dispatch (implementation step, `_dispatch-protocol.md`
"Bounded-join ≠ serial execution"). EARLIEST-CLOSE: `none` (from
`scripts/ai-dlc/validate-ac-falsifiability.sh --stories-dir _bmad-output/planning-artifacts/s323/stories`).

## Ownership (files each story writes)

| Story | Owns (writes) | Role |
|---|---|---|
| 1.1 | rebalancer/execution.py (`_estimate_gas` retry + LAYER re-baseline), rebalancer/tests/test_s323_1_1_*.py | dev-escalated |
| 1.2 | rebalancer/execution.py (merkl claim gas fields), rebalancer/tests/test_s323_1_2_*.py, test_s319_4_2_merkl_claim.py | dev-escalated |
| 1.3 | rebalancer/execution.py (`:22060` standalone collect), rebalancer/tests/test_s323_1_3_*.py | dev-escalated |
| 1.4 | rebalancer/execution.py (Permit2 renewal/broadcast + subscribe caps), rebalancer/tests | dev-escalated |
| 2.1 | rebalancer/execution.py (HODL leaf zero-address), rebalancer/tests | dev |
| 2.2 | rebalancer/execution.py (interim native-input refusal), rebalancer/tests | dev |
| 2.3 | rebalancer/execution.py (native Leg 1 pays-by-value), rebalancer/tests | dev-escalated |
| 3.1 | scripts/ (lazy dotenv), scripts/tests/test_s323_env_sentinel.py | dev |
| 3.2 | scripts/ + web browser smoke tests + test-results (removes 3.1's fixture) | dev-escalated |
| 4.1 | docs/escalations/pending.md, gate-log entries, carry-over-backlog.md | dev |
| 4.2 | `_bmad-output/implementation-artifacts/s323/` 903b record + Check 928 clause entry | dev |
| 4.3 | infra/ staging + `_bmad-output/implementation-artifacts/s323/story-4-3-staged-evidence.md` | dev |
| 4.4 | server/ (aggregator forwards client cert), server tests | dev |
| 5.1 | web/src (DashboardPage rewards cards) | dev |
| 5.2 | rebalancer/ (busy marker, Base claim reachability) + staged PUT artifact | dev-escalated |
| 5.3 | web/src (PortfolioPage TEL card) | dev |
| 5.4 | web/src (RebalancerPage, ConfigEditor collapsed default) | dev |
| 5.5 | web/src (RebalancerPage, CollectFeesSection, DocumentationPage renames) | dev |

## Edges (real dependencies only)

- `rebalancer/execution.py` shared-file chain, order LOCKED by test-strategy.md §4 step 1:
  1.1 → 1.2 → 1.3 → 1.4 → 2.1 → 2.2 → 2.3 → 5.2
- 5.4 → 5.5 (shared: RebalancerPage.jsx, DocumentationPage.jsx)
- 3.1 → 3.2 (by-content: 3.2 AC4 removes 3.1's `_no_operator_signing_key_env` fixture; 3.1 AC6 is the pre-removal leg)
- 5.1 → 4.1 (by-content: 4.1's AC5 panel-half close keys on the 5.1 merge — the record is written after; 4.1 dev work proceeds, the close line lands at 4.1's close-out)

## Waves

- **Wave 1 (parallel, 9):** 1.1, 5.1, 5.3, 5.4, 3.1, 4.2, 4.3, 4.4 — and 4.1 (its 5.1-keyed close is a close-out write, not a dispatch dependency).
- **Wave 2:** 1.2 (after 1.1), 5.5 (after 5.4), 3.2 (after 3.1).
- **Wave 3:** 1.3 (after 1.2).
- **Wave 4:** 1.4 (after 1.3).
- **Wave 5:** 2.1 (after 1.4).
- **Wave 6:** 2.2 (after 2.1).
- **Wave 7:** 2.3 (after 2.2).
- **Wave 8:** 5.2 (after 2.3; also gated by 1.2's gas-gate return for its AC5 test).

Held lines (every non-wave-1 story):
- held: 1.2 — unblocks when 1.1 merges (execution.py)
- held: 1.3 — unblocks when 1.2 merges
- held: 1.4 — unblocks when 1.3 merges
- held: 2.1 — unblocks when 1.4 merges
- held: 2.2 — unblocks when 2.1 merges
- held: 2.3 — unblocks when 2.2 merges
- held: 5.2 — unblocks when 2.3 merges (and 1.2 merged)
- held: 5.5 — unblocks when 5.4 merges (RebalancerPage.jsx, DocumentationPage.jsx)
- held: 3.2 — unblocks when 3.1 merges (fixture removal)

## Step-0 baselines (must exist before the rebalancer story gates)

1. Sprint-base failing-set capture, full `rebalancer/tests` (`.venv-ci/bin/pytest -n auto`, tee'd) — lead, this checkout.
2. Combined one-process baseline `server/test_*.py rebalancer/tests` (tee'd) — lead, this checkout.
3. 3.2 AC1 pre-change full-profile smoke baseline + read-only `/rebalancer-base` load — ops role (lead never runs live prod capture).
4. 1.1 AC10 per-instance CloudWatch warning baseline (read-only) — ops role.
