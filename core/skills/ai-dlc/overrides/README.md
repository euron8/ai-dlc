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

## Clauses (enforced)

Every clause below is declared in `layer-contract.yaml`, bound to the enforcer that fires on it,
and joined to this file by invariants I36-I38 — a clause with no live enforcer fails the
distribution build, as does an enforcer status no clause claims. The prose above is the
rationale; these are the rules. **ERROR** blocks (a non-zero validator exit, or a `HARD-`
status that stops `apply`); **WARN** reports and never blocks.

- **[LC-O1]** ERROR — an override declares `shadows:` and `base_sha:`, and `base_sha` is 7-40
  hex characters.
- **[LC-O2]** ERROR — `base_sha` is a DISTRIBUTION sha. A correct one never resolves in your own
  repo; a consumer sha leaves drift detection silently dead for that entry.
- **[LC-O3]** ERROR — the file named by `shadows:` exists in core. `shadows:` may list several
  comma-parts, and a part that starts with `#` inherits the file from the part before it — so
  `a.md#One, #Two` and `a.md#One, a.md#Two` are the same declaration. Every part is checked under
  the file it resolves to. A FIRST part with no file has nothing to inherit and is an error: it
  names no target, so no file or anchor check on it can run.
- **[LC-O4]** ERROR — `base_sha` resolves in the distribution. One that resolves in neither repo
  makes drift undecidable rather than absent.
- **[LC-O5]** ERROR — `base_sha` is not a consumer sha at pull time either. Both the
  authoring-time and the pull-time check are required: the first is skippable, the second is not.
- **[LC-O6]** ERROR — when the shadowed core section's text changes between `base_sha` and the
  incoming ref, the override is adjudicated before `apply` proceeds. You read the override, not
  core, so an unadjudicated drift is how a core fix lands while you go on running the rule it
  replaced.
- **[LC-O7]** WARN — a whole-file shadow whose file changed is surfaced for re-confirmation. The
  section cannot be proven safe, so it is never silently skipped.
- **[LC-O8]** WARN — an anchor that no longer exists in the incoming ref is reported; upstream
  restructured and the shadow now points at nothing.
- **[LC-O10]** ERROR — an override declares `reason:`. It is the only record of WHY you diverge,
  and a later re-adoption has nothing to adjudicate the divergence against without it.
- **[LC-O11]** ERROR — every `shadows:` anchor is a heading the target file FORWARD-matches (the
  heading contains your anchor). An anchor that instead CONTAINS the heading declares a finer grain
  than a heading — a paragraph, a sub-clause, a renamed section — which the resolver cannot
  address, so it silently widens your shadow to that WHOLE section. The error names the exact
  heading to substitute.
- **[LC-O12]** WARN — every `shadows:` anchor still FORWARD-matches at PULL time. LC-O11 asks the
  same question at authoring time, in a validator you run and can skip; the pull cannot be
  skipped, and it reads the anchor against the INCOMING core rather than the copy on disk.
- **[LC-O13]** WARN — no two entries declare the same (target file, normalised anchor). Both
  bodies claim that span and precedence picks one silently, so which one governs is an ordering
  accident neither entry declares — and every upstream commit touching the span invalidates BOTH
  `base_sha` stamps, so reconciling one of them looks complete. A deliberate split is allowed;
  say so in the bodies.
- **[LC-O9]** WARN — an override's body does not delegate to a construct defined inside a section
  it shadows. Precedence replaces that section at load time, including the delegation target, so
  it reads as a correct single-source delegation and behaves as a dropped one.
- **[LC-O14]** WARN — an override's body does not assert that the section it shadows is unchanged
  or still governs. Same mechanism as LC-O9, opposite failure: precedence replaces the WHOLE
  shadowed span, so a body that rewrites one paragraph of a multi-paragraph section and states
  that the rest still governs is false about its own effect. LC-O9 points the reader at text that
  is gone; this one tells the reader the text is still there, which is why nobody goes looking for
  it. The remedy is the same pair: narrow `shadows:` to the sub-heading actually rewritten, or
  restate the surviving text in the override body.

## Authoring routing (§7.1 — enforced)

The retro / rule-authoring loop MUST land a *change to an existing core rule*
here as an override, never as an in-place edit of the core file. A sprint diff
that edits a core-manifest file without a matching override FAILS the
gate-validation **Core-layer immutability** check.
