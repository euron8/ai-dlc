---
paths:
  - "core/fixtures/**"
  - "scripts/install.sh"
  - "scripts/uninstall.sh"
---

# Whether a fixture ships is ONE declaration, and it lives in the fixture

A fixture ships to consumers unless its own directory carries a `.dist-only` file.
**`install.sh` derives its copy loop from that marker**; nothing hand-lists the shipped
set there any more.

**The criterion: a fixture is `.dist-only` when its SUBJECT is not present on a
consumer.** Three measured shapes, and they are the whole of today's twelve:

- the subject is a distribution-only program (`scripts/validate-enforcement-map.sh`,
  `validate-plan-shape.sh`, `suite-content-key.sh`, the distribution `.githooks/pre-push`);
- the subject is a corpus only this repo holds, so the same run on a consumer scans a
  smaller set and prints the same clean line — a narrower check reading identically to a
  full one;
- it is a MUTATION BATTERY behind a shipped fixture, editing copies of core's own sources.

**Write the reason in the marker.** It is required to be non-empty, because a marker with
no reason is a decision nobody can audit — and seven of the twelve were zero bytes until
this rule existed. Getting it wrong in the shipping direction is how a distribution-only
battery once became the reference consumer's suite pole; getting it wrong the other way
means a fixture reaches no consumer while this repo's own suite stays green over it.

**Three hand-written lists remain and they are deliberate.** `uninstall.sh` bounds a
DESTRUCTIVE loop and runs on a consumer where `core/fixtures/` does not exist, so it cannot
derive and must not glob the consumer's `tests/fixtures/` — that would delete fixtures the
consumer wrote. `core-manifest.md` and `setup-sites.md` are glob declarations read by
roughly twenty programs. All three are joined to the derived set by **I74**, in both
directions — so they can be stale for exactly as long as one push.

---

NOTE: the wildcard-with-exclusion alternative for `core-manifest.md` and `setup-sites.md`
was considered and rejected. Those two are read by roughly twenty programs (the core guard
hook, `core-paths.sh`, `validate-layer-entries.sh`, the drift scan, a dozen fixtures);
changing their grammar touches every one of those readers, and that blast radius is larger
than the four edits it would save. This is the history of a settled decision, not a live
constraint — it is here so the question is not reopened, and it prescribes nothing.
