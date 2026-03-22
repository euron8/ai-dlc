# Pattern: Deployed Bundle Verification

**Category:** Deployment integrity
**Gate check:** #8 (Deployment evidence), #9 (Visual verification)
**Severity:** Critical for UI changes — deploy failures are silent

## What it does

After every deployment that changes UI assets (CSS, JS), fetch the
deployed bundle and verify the changed selectors/properties are present
in the minified output. This catches duplicate selectors, build caching
issues, and silent deploy failures.

## When to use

Install this pattern when your project has a frontend build pipeline
that produces minified assets. Applies to any framework with a build
step (React, Vue, Next.js, etc.) deployed behind any CDN or server.

## Configuration

Add to your project's `docs/coding-conventions.md`:

```markdown
### Bundle Verification

After every UI deploy, fetch the deployed CSS/JS bundle and verify
changed selectors/properties are present in the minified output.
**Evidence required:** Log the bundle URL, hash, and grep output in
the story file under "Bundle Verification". Gate validation check #8
requires this evidence.

Bundle URL pattern: {bundle_url_pattern}
Verification command: {bundle_verify_command}
```

## Template variables

- `{bundle_url_pattern}`: How to find the deployed bundle.
  Example: `https://your-app.com/static/js/main.*.js`
- `{bundle_verify_command}`: Command to verify bundle contents.
  Example: `curl -s <bundle_url> | grep -c 'your-changed-selector'`

## Origin

Graph project Sprint 45 — CSS `gap: 8px` change was deployed 8 times
without ever rendering. A duplicate `.pool-card-detail-sections` selector
silently swallowed the property. Fetching the minified bundle and
grepping for the selector would have caught it on the first deploy.
