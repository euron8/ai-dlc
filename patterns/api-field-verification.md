# Pattern: API Field Verification for UI Components

**Category:** Cross-layer contract verification
**Gate check:** #6 (Production integrity tests), code review mandatory severity
**Severity:** Important minimum — synchronized fixture/schema bugs bypass all testing

## What it does

For every UI component that displays API data, verify that every field
accessed in the component code exists in the actual API response. The
field list must come from a systematic grep of the component, not from
manual enumeration.

## When to use

Install this pattern when your project has a frontend that consumes API
endpoints and displays the data. Applies to any UI framework (React, Vue,
Svelte, etc.) consuming any API format (REST, GraphQL, gRPC).

## Configuration

Add to your project's `docs/coding-conventions.md`:

```markdown
### UI Field Verification

Stories that display API data must include a "Consumed API Fields"
section in the story spec listing:
- Endpoint URL
- Every response field accessed in the component
- Field types

**Evidence required:** The field list must be derived from a systematic
grep of the component file for response field access patterns
(`.field_name`, `["field_name"]`, destructuring). Log the grep command
and output in the story file. Code review must verify every field exists
in the actual API response — unverifiable fields are Important severity.
```

Add to `code-reviewer.md` under Mandatory Severity Classifications:

```markdown
### Unverifiable API Field Names = Important

Any field name in UI component code that cannot be verified against the
actual API response MUST be classified as **Important**. Include a
Field Verification section in the review doc.
```

## Origin

Graph project Sprint 42 — accordion component used invented field names
(`confidence_score`, `recommendation`, `revenue_sensitivity`) that don't
exist in any API response. Test fixtures used the same names, so all
tests passed. Three production bugs shipped through all three gates.
