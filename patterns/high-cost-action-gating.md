# Pattern: High-Cost Action Gating

**Category:** Destructive/expensive operation protection
**Gate check:** Integrated into gate-validation.md artifact consistency
**Severity:** Critical — expensive operations are irreversible or costly

## What it does

Before executing any operation that is expensive, slow to reverse, or
irreversible, agents must verify explicit authorization exists (a planned
story or direct user approval). No ad-hoc expensive operations.

## When to use

Install this pattern when your project has operations with asymmetric
cost — cheap to trigger, expensive to undo. Examples: database migrations,
cache invalidation, reindexing, cloud resource provisioning, blockchain
transactions, production data modifications.

## Configuration

Add to your project's `docs/coding-conventions.md`:

```markdown
### Impact Classification

| Change Type | Cost / Reversibility | Minimum Planning Level |
|---|---|---|
{impact_classification_rows}

### High-Cost Action Gates

Before executing any operation classified as "High cost" or above,
agents must verify that a planned story exists authorizing the change.
Before executing any "Very high cost" or "Irreversible" operation,
agents must verify explicit user approval exists. If neither exists,
the agent must stop and inform the lead.
```

## Template variables

- `{impact_classification_rows}`: Project-specific rows. Examples:
  - `| Database migration | High cost, minutes to rollback | Planned story |`
  - `| Cache invalidation | Medium cost, rebuilds in background | Commit directly |`
  - `| Blockchain transaction | Irreversible, costs gas | Requires explicit approval |`

## Origin

Graph project — subgraph mapping changes trigger a 6-hour reindex.
A one-line fix has the same reindex cost as a 500-line feature. Multiple
incidents of ad-hoc subgraph changes causing unnecessary reindexes.
