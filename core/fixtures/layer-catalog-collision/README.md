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
| 30 | *(absent)* | Smoke test evidence (deploy-validate) | nothing — extension-only |
| 33 | Test-strategy deliverable presence *(as core 21)* | Cross-story test-strategy deliverable presence | `RESTATES-CORE (renumbered)` — same check, DIFFERENT number |

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

## Run

```sh
tests/fixtures/layer-catalog-collision/run.sh
```

Exit 0 = the classifier reports all four states correctly and does not emit the false
absorption. Non-zero = a detector regressed.
