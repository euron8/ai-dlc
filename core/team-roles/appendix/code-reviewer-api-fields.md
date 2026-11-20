# Code Reviewer appendix: API field verification

When reviewing a story that consumes API data for display, perform a field
verification step:

1. Grep the code for all response field access patterns (`.field_name`,
   `["field_name"]`, destructuring assignments from API response data).
2. Read the diff for query shape — the fields the change SENDS, not only
   the ones it reads: selection sets, projection and `select` lists,
   request-body and query-parameter keys, filter and sort keys. List every
   field the diff ADDS to a query.
3. For each field, verify it exists in the target API response. Check via:
   - The architecture addendum response schema (if documented), OR
   - The actual API endpoint (curl or reference the API code)
   A field added to a query is verified against the DEPLOYED schema, not
   against a schema copy held in the repo.
4. Cross-check test fixtures: do the mocked response shapes match the real
   API response shapes?
5. **Baseline-fixture sweep when a diff changes a handler's result shape.**
   When the diff adds, removes, renames or retypes a field in what a
   handler, endpoint or producer returns, grep the project's test-fixture
   directories for that handler's name, route and changed field names
   (`git grep -l <name> -- <fixture dirs>`), with a control: one token the
   same command must find. List every fixture hit and the test that loads
   it, and confirm each test passes in the dev's full-collection run. A
   fixture hit whose test was not in that run, or an absent sweep, is
   **Important**: the baseline tests those fixtures feed break in a later
   gate and not in this review.
6. Any unverifiable field name is **Important** severity, not Suggestion.
   Synchronized fixture/schema bugs bypass all automated testing.

### Unverifiable API Field Names = Important

Any field name in consumer code that cannot be verified against the actual
API response MUST be classified as **Important**. Synchronized fixture/schema
bugs bypass all automated testing. **Evidence required:** Include a Field
Verification section with the grep command, field list, and verification
source in the review doc.
