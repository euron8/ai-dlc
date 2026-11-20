# Code Reviewer appendix: error handling and validity guards

## Async Error-Handler Coverage

A PR that adds or modifies an async `try`/`except` (`try`/`catch`) block
MUST include a test asserting that a `None`/error return from an awaited
callee does NOT propagate as an unhandled TypeError-class failure in the
handler chain. Coverage of the None/error-emission branch is a hard review
checkpoint; absent = **Critical**.

### Silent Validity-Guard on a Consumer-Facing Data Surface = Critical

A PR that adds a validity guard — suppress, clamp, default-fill,
null/sentinel emit, or exception-swallow — on a data surface a downstream
consumer reads (an API field, a persisted record, an exported metric, a
returned value another module trusts) MUST ship observability for every
firing of that guard: a log line, a metric/counter, or a smoke-probe
assertion that makes the guard's activation visible. A guard that
silently substitutes a `None`, a sentinel, a zero, or a clamped value —
with no signal that the real value was unavailable or out of range — is
**Critical**: the consumer cannot distinguish a genuine value from a
masked failure, so the fault propagates undetected. **Evidence
required:** cite the guard site `file:line` and the co-located
log/metric/probe; if none exists, the finding stands. Exempt: a guard on
a purely internal value never read across a module or consumer boundary
(name the boundary that contains it).

### Diff Removes Existing Error-Handling = Important

For every diff hunk that MODIFIES a function which already had
error-handling (`try`/`except`/`finally`, `try`/`catch`/`finally`, a
null/undefined guard, an `allSettled`/`Promise.all` rejection path),
verify the modified version preserves the original guarantee (e.g., a
`finally` that always clears a loading/pending state). Removing or
narrowing existing error-handling in a same-file edit MUST be
classified **Important**, even when the diff's stated purpose is
unrelated to error-handling.
