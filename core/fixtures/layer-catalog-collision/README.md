# layer-catalog-collision — adversarial fixture

Proves that the consumer-catalog namespace is a MECHANISM and not a declaration.

`steps/gate-validation.md` ("Consumer-catalog crosswalk") has always said that a
consumer's `extensions/checks/` numbers are a separate namespace, that they must be
aligned by title and never by number. Nothing implemented it. Extensions are additive,
so core's checks and a consumer's extension checks render into ONE merged list under
the SAME integers, and the lead then writes a bare `Check 24: PASSED` into the gate
log — the durable audit record. The rule put the whole burden on recall at exactly the
moment the number became permanent evidence.

This fixture pins the four states the detectors must tell apart, and the two ways they
were previously blind.

## What it seeds

A synthetic core file and a synthetic extension that hooks it:

| number | core | extension | must report |
|---|---|---|---|
| 5 | Story status consistency | Story status consistency | `RESTATES-CORE` — same number, same title (Rule 27(c)) |
| 7 | Artifact consistency | *(absent)* | nothing — core-only |
| 9 | Smoke test coverage for user-facing changes | *(absent)* | nothing (see the trap below) |
| 24 | The adversarial cycle CONVERGED | Financial-display ground-truth live-verify | `CHECK-NUMBER-COLLISION` — same number, DIFFERENT check |
| 30 | *(absent)* | Smoke test evidence (deploy-validate) | `OUT OF BAND` only — no collision to report yet, which is the point |
| 33 | Test-strategy deliverable presence *(as core 21)* | Cross-story test-strategy deliverable presence | `RESTATES-CORE (renumbered)` — same check, DIFFERENT number — plus `OUT OF BAND` |
| 40b | *(absent)* | Suffixed allocation beside core's 40 | nothing — a suffix marks a position, not an allocation |
| 933 | *(absent)* | In-band consumer allocation | nothing — the conformant state |

## The two blindnesses this fixture exists to catch

**1. The number-keyed join.** A detector that joins extension anchors to core anchors
by NUMBER cannot see either of the interesting cases. Same-number/different-title (24)
produces no status at all — not a retirement candidate (correctly), but not anything
else either, so the collision is invisible to the very tool built to surface layer
drift. And same-title/different-number (33) is invisible in the other direction: a
check upstream has already absorbed, duplicated forever, because the join key says the
numbers differ. A real consumer carried two such duplicates for ~35 minor versions,
both of them documented in core's own prose, and no pull ever mentioned them.

**2. The loose title match.** Once the title becomes a join key, it must be tight.
Core's check 9 ("Smoke test **coverage** for user-facing changes") and the extension's
check 30 ("Smoke test **evidence**, deploy-validate") share `{smoke, test}` — enough
for the old `same_section()` rule (≥2 shared tokens of the first 4) to call them the
same section. Acting on that would emit a RETIRE-CANDIDATE for a live deploy-validate
check on a financial system: a reporting tool turned into a data-loss bug. **The
fixture FAILS if 30 is matched to 9.** A loose title match is worse than no title match.

**3. The number nobody has taken yet.** Both blindnesses above are properties of a
COLLISION detector, and a collision detector joins against the numbers core defines
*today*. A consumer allocating check 33 while core stops at 32 therefore matches
nothing and reports clean — correctly, by every rule above — until the release where
core allocates 33, and then the collision appears retroactively across every gate log
already written. The defect is created at authoring time and detected, if ever, by an
unrelated party several releases later. No better detector reaches it: the subject set
"numbers core has already taken" cannot contain the number an author is about to take.

The fix is a partition rather than a detector. Core allocates below `BAND_FLOOR`, a
consumer allocates at or above it, and the collision stops being reportable because it
stops being constructible. Part 5 asserts the four exclusions that keep the band off
the cases it must not govern — a suffixed id (`40b`) marks a position beside core's
number, an alphabetic id has no ordering, a number core already defines belongs to the
collision arms, and a step-domain step number is a position in a procedure. Part 6
mutates each exclusion out and requires a NEW finding to appear, because the suffix
exclusion in particular passes its own pristine assertion whether it is present or not.

Core's half of the same partition is invariant **I45** in
`scripts/validate-enforcement-map.sh`, tested by the `enforcement-map-sites` fixture.
Without it the band is a promise to consumers with nothing holding core to it.

## Run

```sh
tests/fixtures/layer-catalog-collision/run.sh
```

Exit 0 = the classifier reports all four states correctly and does not emit the false
absorption. Non-zero = a detector regressed.
