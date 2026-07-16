# audit-anchors-schema fixture

Adversarial self-test for `core/scripts/validate-audit-anchors.sh` and its
canonical schema `core/schemas/audit-anchors.json`.

## Why this exists

The audit-anchors housekeeping schema used to live in two places — the
`templates/audit-anchors.md.template` header (never shipped to a consumer) and
each project's live `_bmad-output/audit-anchors.md` header (hand-carried forward
by the retro) — with nothing comparing them. They drifted: the live header grew
an `audit_window` field and a YAML-list form while the template stayed on
`---`-separated docs with a `notes` field. The de-facto schema survived only in
whichever file was carried forward, and a fresh install would have seeded the
stale shape. Same class as the provenance-block defect (v0.60.0): N hand-synced
copies of one schema, nothing comparing them.

The cure is one definition (`schemas/audit-anchors.json`): the reader loads it,
the header is rendered from it, `--check` byte-compares, and the entry validator
loads it. This fixture drives the REAL validator to prove it.

## What `run.sh` proves

- `--render` is non-empty and deterministic (the render is the source of truth);
- a rendered header + well-formed entries → validate PASS;
- a hand-edited header region or a missing region → `--check` FAIL (drift caught);
- an entry missing the required `sha`, or a non-integer `sprint` → validate FAIL
  (fail-closed on the structural shape a reader depends on);
- a real `sha` with a trailing inline `# comment` → PASS (the parser strips it);
- `--entries` passes a headerless (pre-schema) file while full validate still
  fails — the migration-safe path so a not-yet-migrated consumer is not wedged
  at gate-validation Check 18 before its next retro re-seeds the header;
- an unreadable/malformed schema → exit 1 (fail-closed, never degrades to
  no-schema).

The schema deliberately enforces STRUCTURE, not the historical FORMAT of values:
verified against the reference consumer's real file, which carries short SHAs,
angle-bracket placeholders, per-sprint `PENDING` variants, and inline comments.
A stricter pattern would wedge a real consumer on first contact.

Run `run.sh`; it seeds a temp tree, drives the validator, and exits non-zero on
any failed assertion.
