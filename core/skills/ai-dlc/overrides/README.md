# `overrides/` — consumer-owned shadow layer

**Owner: the consumer. Upstream NEVER writes here.** `/ai-dlc-update` overwrites
`core` and leaves this directory untouched.

An override *shadows a specific core rule or check* — the settings.json-upsert
pattern applied to the rulebook. Use it when a consumer must deliberately CHANGE
an existing upstream rule (not add a new one — that is `extensions/`). Overrides
are the entire residual three-way surface after Phase 2: a pull overwrites core,
then reconciles only this small set.

## Entry contract

Filename: mirror the target for legibility, e.g.
`steps__gate-validation__Check-14.md`, `SKILL__Rule-19.md`.

```markdown
---
shadows: steps/gate-validation.md#Check 14   # exact core target: file + rule/check id
base_sha: <dist sha>                          # the distribution sha of the core rule
                                              # WHEN THIS OVERRIDE WAS AUTHORED
reason: <one line — why this consumer changes the core rule>
---

<the replacement / patched body that shadows the core rule for this consumer>
```

## Precedence & loading

At pipeline start the loader (SKILL.md Rule 27) applies overrides LAST:
`overrides > extensions > core`. When a core rule and an override both define the
same id, the override body wins for that run.

## Override drift (spec §10)

A core rule you shadow can itself change upstream. `base_sha` is the anchor for
the override's own three-way: on `/ai-dlc-update`, if the core target changed
between `base_sha` and the new upstream sha, the reconcile surfaces the override
for re-confirmation (has upstream's change to that rule superseded your reason?).
Keep `base_sha` current whenever you revise an override.

> **`base_sha` is a DISTRIBUTION sha — not one from this repo (Rule 27(a)).**
> The reconcile runs `git diff <base_sha>..<theirs>` inside the *distribution*
> checkout. A sha copied from your own project's history (e.g. the
> `chore(ai-dlc-update): reconcile …` commit that performed the last pull) does
> not exist there, the diff dies on `fatal: bad revision`, and drift detection is
> **silently dead** for that entry — upstream changes are lost to a stale shadow
> with no warning.
> Rule of thumb: **a correct `base_sha` never resolves in your own repo.**
> `scripts/ai-dlc/validate-layer-entries.sh` errors on a poisoned one;
> `/ai-dlc-update` reports it as HARD and refuses to `apply` until it is fixed. This residual three-way
is small but not zero — it is the price of deliberately diverging from a core rule.

## Authoring routing (§7.1 — enforced)

The retro / rule-authoring loop MUST land a *change to an existing core rule*
here as an override, never as an in-place edit of the core file. A sprint diff
that edits a core-manifest file without a matching override FAILS the
gate-validation **Core-layer immutability** check.
