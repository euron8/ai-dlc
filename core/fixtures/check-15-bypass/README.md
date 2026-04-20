# Check 16 (Stub Audit) Bypass Fixture

Historical name: check-15-bypass (fixture dir keeps historical name per
LR-S155-3 wording; the renumbered check is Check 16).

Scenarios:
- Stub with fictional `Item 999` reference (item doesn't exist in backlog)
- Stub with TBD deferral-reason
- Stub with no file:line reference
- Stub with padding-only deferral-reason (bypasses naive length check)

Strengthened Check 16 catches all four variants.

Run `seed.sh` to reproduce idempotently.
