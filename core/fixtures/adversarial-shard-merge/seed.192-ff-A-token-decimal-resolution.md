# Story 192-FF-A: Fix Token Decimal Resolution

## Context

The aggregator queries the subgraph for token metadata (decimals, symbol)
via `token(id:"{address}")` GraphQL query. This query returns null for all
tokens in production, causing decimals to default to 18. TEL has 2 decimals,
USDC has 6 — the 1e16 and 1e12 scaling errors corrupt ALL financial
calculations: IL, entry values, fees, net PnL.

Evidence: all pools return `pool_pair: "TOKEN0/TOKEN1"` in production API.
WETH pool shows $2.1M lifetime IL (impossible). USDC pool shows $2.85e-06
