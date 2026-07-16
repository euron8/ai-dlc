# core-write-guard fixture

Adversarial self-test for `core/hooks/ai-dlc-core-guard.sh` — the `PreToolUse`
hook that makes it structurally impossible for a layered consumer to edit a core
(upstream-owned) file in place.

## Why this exists

Rule 27 forbids a consumer editing a core-manifest file in place, but until this
hook nothing STOPPED it at the keystroke. The retro-gate `Core-layer immutability`
check catches it a whole sprint late — and by then `/ai-dlc-update` has a
`BOTH-CHANGED`-on-core prose merge to untangle, the one irreducibly-semantic case
left in a pull. The hook denies the write as it happens and routes it to
`overrides/` or `extensions/`, so `BOTH-CHANGED`-on-core becomes rare by design.

A green hook proves nothing on its own; this fixture drives the REAL hook with
synthesized `PreToolUse` JSON on stdin and asserts the decision each way.

## What `run.sh` proves

Against a real layered-consumer tree (`seed.sh` copies the actual
`core-manifest.md`, `reconcile/setup-sites.md`, and the real token-bearing role
files, so the derivation and the config-region exemption are tested against the
shipped declarations, not stand-ins):

- an in-place Edit to a core step file → **deny**, and the deny message **routes**
  the author to `overrides/` and `extensions/`;
- an Edit to an `overrides/` or `extensions/` entry → **allow**;
- a Bash shell write to core (the shape `apply.sh` uses) → **allow** — the hook
  matches only `Edit|Write|MultiEdit`, so the whole update flow is exempt;
- an Edit to core in an unstamped tree (the distribution) → **allow** (no-op);
- an Edit filling a declared `/ai-dlc-setup` site — a team-role model string, a
  `dev.md ## Ownership` heading-block — → **allow**;
- an Edit to a rulebook line of that SAME config-bearing file → **deny** (the
  region check is line-precise, not whole-file);
- a whole-file `Write` of a core file → **deny** (never a token fill);
- a `MultiEdit` touching core rulebook → **deny**;
- with `core-manifest.md` removed, the core set is derived from
  `setup-sites.md`'s I5-synced copy and the deny still fires (derivation fallback);
- with no manifest source at all, the hook **fails open** (allow) — it never
  wedges a pipeline on ambiguity.

Run `run.sh`; it seeds a fresh temp tree, drives the hook, and exits non-zero on
any failed assertion. The `seed.sh`/`run.sh` split mirrors the other reconcile
fixtures.
