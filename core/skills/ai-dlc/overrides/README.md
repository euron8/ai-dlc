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
conforms_to: <n>                              # the contract version you migrated this entry to
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
- **[LC-O15]** ADJUDICATED — an entry ANY ONE of whose `shadows:` anchors matches a core
  `override_supersessions:` declaration is reported RETIRABLE, not merely drifted. Every other
  status here asks whether the entry is still correct; this one asks whether it is still NEEDED,
  and it is the only one whose answer is to stop shadowing. A superseded override otherwise
  presents as ordinary section drift — which reads as re-adopt-the-new-wording — so it survives
  the pull and goes on freezing every unrelated line in its shadowed span at `base_sha`.
  **The join is per anchor, and the remedy depends on how many you declare.** A one-anchor entry
  is retired outright with `readopt-override.sh --stamp retire`, after applying the declared
  replacement. A multi-anchor entry is NARROWED instead: remove the superseded anchor from
  `shadows:` and leave the rest byte-untouched, because that stamp deletes the whole file and
  core has superseded only one of the anchors. The row tells you which case you are in, and
  `apply.sh` renders the action rather than the choice.
  **And it tells you the SIZE of what you are about to drop, because core may have superseded one
  ARM of an anchor while your span under it carries lines core does not have.** The row compares
  your span against core's *at your entry's own `base_sha`* — that is what an override froze — and
  names how many of your lines appear nowhere in core's. On the consumer that reported this, the
  count was 119, against a remedy that read like housekeeping. If those lines are yours and you
  still want them, the answer is `still-additive` with a reason, not a narrowing you undo next
  sprint. **Do not expect core to declare the arm instead**: `override_supersessions` names a
  file and an anchor, the real case's core span carries one sub-heading with the superseded
  machinery on both sides of it, and the other superseded arm is not in that file at all — so the
  number is the mechanism, and the reading is yours. If either span cannot be read the row says
  so rather than going quiet.

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
- **[LC-O16]** WARN — every section of an override's body is claimed by one of its `shadows:`
  anchors. LC-O9 and LC-O14 ask whether the body describes its own effect truthfully; this asks
  whether the body is REACHED. The body is sliced PER ANCHOR, so a section no anchor names is
  applied by nothing: it renders nowhere and reaches no lead while it still reads, in the file, as
  live consumer machinery. **It is reached by REMOVING an anchor and leaving the body — exactly
  what LC-O15's narrowing remedy instructs for a multi-anchor entry — so read the two together and
  do not execute an LC-O15 narrowing without checking this.** A body that restates no shadowed
  heading is the single-anchor shape and is silent here; only a heading at a level some claimed
  heading also uses is reported, because framing prose is not a failed claim. Remedy: restore the
  anchor to `shadows:`, move the text under a section an anchor does claim, or delete it.

## Authoring routing (§7.1 — enforced)

The retro / rule-authoring loop MUST land a *change to an existing core rule*
here as an override, never as an in-place edit of the core file. A sprint diff
that edits a core-manifest file without a matching override FAILS the
gate-validation **Core-layer immutability** check.
