# Pattern: GraphQL Schema Verification

**Category:** Pre-deploy field verification
**Gate check:** #10 (Schema/API field verification)
**Severity:** Critical — causes production errors when violated

## What it does

Before any new field is added to a GraphQL query, verify the field exists
in the live schema via introspection. If the field doesn't exist, the
query change must be gated behind schema deployment.

## When to use

Install this pattern when your project queries a GraphQL API (subgraph,
Hasura, Apollo, custom) and schema changes require a deployment step
(e.g., subgraph reindex) before new fields are available.

## Configuration

Add to your project's `docs/coding-conventions.md`:

```markdown
### GraphQL Schema Verification

Stories that introduce or modify GraphQL queries must verify all queried
fields exist on the target entity via live introspection. **Evidence
required:** Run introspection query against the live endpoint and log
the result in the story file under "Schema Field Verification". Gate
validation check #10 will verify this evidence exists.

Introspection query:
\`\`\`graphql
{introspection_query}
\`\`\`

Endpoint: {graphql_endpoint}
```

## Template variables

- `{introspection_query}`: The introspection query for your schema.
  Example: `{ __type(name: "Pool") { fields { name } } }`
- `{graphql_endpoint}`: Your GraphQL endpoint URL or env var reference.
  Example: `$GRAPH_STATUS`

## Origin

Graph project Sprint 44 — Story 84-2 added `sqrtPriceX96` to all 7 pool
queries before the subgraph was deployed. GraphQL rejected the unknown
field, causing 503 on all queries.
