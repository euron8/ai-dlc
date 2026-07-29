# `extensions/` — consumer-owned additive layer

**Owner: the consumer. Upstream NEVER writes here.** `/ai-dlc-update` overwrites
`core` (the upstream-owned rulebook files) and leaves this directory untouched.

This is where a consumer's *net-new* machinery lives — rules, gate-checks, and
domain step logic that upstream intentionally does not carry. Fencing it here
(instead of editing core in place) is what keeps `core` byte-reconcilable with
upstream, so a pull is a clean overwrite of core plus a small `overrides/` merge
— never a whole-rulebook tangle.

## Layout

```
extensions/
  checks/          new gate-validation checks (domain gates, extra audits)
  steps-domain/    domain additions to a pipeline step (execution-health floors, deploy gates, …)
  roles/           additions to a team-role (domain review patterns, extra constraints)
  known-skills.json  extra skill names a consumer's own personas emit (data extension, see below)
```

## Data extensions (not `.md` rule entries)

A few layer points are **data**, not a `kind:`-tagged rule: a consumer-owned JSON file the
reader that owns a core *list* unions in. They carry no frontmatter and no `hooks:` — the layer
loader and `validate-layer-entries.sh` process only `*.md`, so a `.json` here is inert to them —
and the owning reader resolves the file by name.

- **`known-skills.json`** — extra skill names a consumer's own party personas or sub-skills cite
  in their `SKILL_INVOCATION_PROVENANCE` blocks. `validate-provenance-block.sh` unions it with the
  core `known_skills` list (`.claude/schemas/provenance-block.json`), so a provenance block naming your
  skill passes **without editing the core schema**. Either shape:

  ```json
  { "known_skills": ["bmad-agent-tea-tea"] }
  ```

  Additive and deduped; a present-but-malformed file fails the gate **closed** (a broken layer
  file must never silently degrade to the core-only list). This is the layer-correct alternative to
  adding a skill name to the core schema in place — which `/ai-dlc-update` flags as
  `HARD-UNREGISTERED-CORE-DRIFT` (schemas are drift-scanned).

- **`protected-paths.json`** — consumer paths that must load VERBATIM, i.e. that
  `ai-dlc-protect.sh` must stop context-mode from consolidating. Core protects the rulebook
  (skill, roles, schemas, `CLAUDE.md`, coding conventions) and the pipeline artifacts it
  itself defines (snapshot, gate log, escalations, audit anchors, sprint status, stories).
  It cannot protect *your* source-of-record locations without shipping one project's
  vocabulary to every other consumer — a project that keeps its architecture SoR at
  `docs/architecture.md` declares that here:

  ```json
  {
    "protected_paths": ["docs/architecture.md", "docs/architecture-index.md"],
    "excluded_paths":  ["docs/architecture-drafts/*"]
  }
  ```

  Both keys optional, string arrays, unioned with the core sets. Entries are matched as
  globs against a project-relative path, so `docs/adr/*.md` works; `excluded_paths` wins
  over `protected_paths` and is how you carve an archive back out. A present-but-malformed
  file fails **closed** — every path the call carries is denied, with the filename in the
  reason — because a broken layer file must never silently degrade to the core-only set.
  Calls carrying no path still pass, so a typo cannot wedge the session.

  What NOT to put here: the planning corpus (`prd.md`, `architecture.md` when it is a
  generated index, `product-brief.md`, `carry-over-backlog.md`) if its byte-exactness is
  already enforced script-side. Rule 24 exists to offload exactly those files, and
  `validate-locked-anchor.sh` resolves every `full_text_source:` against the SoR on disk,
  so a consolidated read cannot forge a passing anchor. Protect what a *model* must quote
  verbatim, not what a *script* already byte-checks.

## Entry contract

Each entry is a markdown file that declares, in frontmatter, where it hooks into
the pipeline so the layer loader (SKILL.md Rule 27) can activate it:

```markdown
---
kind: check | step-domain | role | qualifier
hooks: steps/gate-validation.md        # the core file/step this augments
id: <stable-id>                        # e.g. exec-health-floor, check-financial-display
push_candidate: false                  # true = generalizable; feeds the ai-dlc-update push-mine / absorption arc
fixtures: check-foo-bypass             # OPTIONAL, `kind: check` only — see below
extends: '#Empirical gate validation'  # OPTIONAL — narrows drift to one section; REQUIRED on kind: qualifier
position: append                       # `kind: qualifier` ONLY — append | prepend
---

<the additive rule / check / step body>
```

**`extends:` — narrow your drift to the section you actually meant.** Optional on every kind.
Without it, your drift subject is the whole hooked FILE, so any change anywhere in it puts this
entry on the re-read worklist. Measured across the reference consumer's 33 entries and the full
history of the 17 core files they hook: **1421 (entry, commit) drift events at file grain against
an expected 133 at anchor grain.** Nine of every ten re-reads are a change to a part of the file
your entry never referred to, and a worklist that is 91% noise is one you learn to clear rather
than read. Declaring the anchor is what buys the other 91% back.

Write it `#Anchor` to mean "in the file I already hook", or `file.md#Anchor` — the file part, if
present, must be the one `hooks:` names. Exactly one anchor: two would mean two spans, and a drift
row could no longer say which one moved. The anchor must name a heading FORWARD (the heading
contains your anchor), not the reverse — see LC-E11.

**`kind: qualifier` — render INSIDE a core section.** The other kinds are additive at file scope:
they render as their own section. A qualifier renders *within* the core section `extends:` names,
at `position: append` or `prepend`, and it carries **no `base_sha` obligation on prose it does not
restate** — which is the whole point. Before this grain existed, a consumer that only wanted to
qualify a core section had to shadow all of it verbatim in `overrides/` and then carry `base_sha`
drift on prose it never meant to change. On the reference consumer that cost **376 of 1126
significant override body lines (33%) byte-identical to the core span they shadow**, and one
override spends **132 lines** to add a single integer to one table cell.

A qualifier is still additive — it does not delete or contradict core's prose, it adds to it. If
you need to *change* what core says, that is still `overrides/` with a `base_sha`.

**`hooks:` path convention.** The value is written `core/`-relative (the same
convention `reconcile/setup-sites.md` and `preclassify.sh` use), NOT relative
to this skill directory:

- `SKILL.md` and `steps/<x>.md` resolve under the skill dir —
  `.claude/skills/ai-dlc/SKILL.md`, `.claude/skills/ai-dlc/steps/<x>.md`.
- `team-roles/<role>.md` (used by `kind: role` entries) resolves to
  `.claude/team-roles/<role>.md` — **outside** this skill dir.

The Rule 27 loader and `ai-dlc-update`'s §7v hooks-existence check both map
the value the same way core files map to consumer files. A naive
skill-relative join would look for `.claude/skills/ai-dlc/team-roles/<role>.md`
and wrongly report every role hook missing.

**`fixtures:` — how a consumer check's fixture reaches H1.** Optional, `kind: check` only.
A comma- or space-separated list of fixture directories under `tests/fixtures/` (the
`tests/fixtures/` prefix may be written or omitted). Core H1 derives its coverage set from
`enforcement-map.yaml`'s `fixtures:` bindings — and that map is upstream-owned and carries no
row for a consumer check, so before this field a consumer that shipped an adversarial fixture
with its check had **no way to bind it**: editing the map is unregisterable core drift the
next `apply` overwrites, and the alternative was a hand-maintained enumeration inside the
extension, which is the exact practice H1's rewrite exists to end. Declaring it here puts the
fixture in the set H1 reads.

The binding is the whole mechanism, so a dangling one is worse than none: it makes H1 report
coverage that does not exist. `ai-dlc-update` reports `EXTENSION-FIXTURE-UNBOUND` for a
`fixtures:` value that is not a directory in the consumer tree, level-triggered — it is a
state of your tree, so a pull that changes nothing here still reports it.

- **Additive only.** An extension ADDS behavior; it never edits a core rule. To
  *change* an existing core rule, use `overrides/` instead.
  - **A restriction is not an addition.** "Only X and Y are valid", "Z is NOT
    subject to", any closed enumeration of what core accepts — these *narrow* a
    core rule and belong in `overrides/` with a `base_sha`. Filed here they carry
    no drift anchor, so when core grows a third valid value your entry silently
    starts contradicting it.
  - **Where this rule is checked.** At the pull, per entry: `EXTENSION-HOOK-DRIFT`
    becomes a `WORKLIST extension-reread` row whose verdict is one of
    still-additive / contradicts-core / retire (`ai-dlc-update/SKILL.md` step 7).
    No scanner enforces it. `EXTENSION-RESTATES-CORE` catches an entry that COPIES
    a core section; an entry that asserts the opposite in its own words copies
    nothing and matches nothing, and an extension has no `base_sha` to compute a
    contradiction against. The re-read is the whole mechanism — if it is skipped,
    this rule is unenforced.
  - **Never restate a core section.** Same heading, or the same step number with
    the same title, means the rendered file defines it twice and a "Step 5c"
    reference becomes ambiguous. An extension's body is *added* to core, not merged
    with it.
  - **Adding a rule that QUALIFIES a core section? Label the heading.** This is the
    case that gets misfiled most often, because reusing the core section's heading
    feels like the natural way to hook onto it — and it is exactly what the rule
    above forbids. Give the entry its own labelled heading instead, the same
    Rule 27(d) pattern check catalogs use:

    ```markdown
    ### 3. [ext:sprint-review-domain] Decision-branch execution coverage.
    ```

    Not `### 3. Fix and Re-Validate` — that is core's heading, and duplicating it
    makes the merged file define one section twice.

    The labelled form renders as its own section, so the reference stays
    unambiguous and `/ai-dlc-update` stops reporting `EXTENSION-RESTATES-CORE`
    against it on every pull. What it does NOT do is render the rule *inside*
    core's section. If that placement is what you want, that is `kind: qualifier`
    with `extends:` and `position:` — see the entry contract above. Reaching for
    an override to get it means replacing the whole section verbatim and then
    carrying `base_sha` drift on prose you never meant to change, which is the
    cost the qualifier grain exists to remove.
- **Label your catalog (Rule 27(d)) — `kind: check` entries.** Your check numbers are
  your own namespace, but they render into the SAME merged list as core's, under the
  SAME integers. So say which catalog a check belongs to, in the heading and in the
  gate-log row:

  ```markdown
  ### 24. [ext:gate-validation-domain] Financial-display ground-truth live-verify.
  ```
  ```
  | [ext:gate-validation-domain] 24 — Financial-display ground-truth | PASS | … |
  | [core] 24 — The adversarial cycle CONVERGED                      | PASS | … |
  ```

  `<id>` is this file's `id:` frontmatter — the same key `GATE_METRIC v1` emits in its
  `catalog` field, so the human render and the machine record agree. **The integer never
  changes**; the label is *added*. So `Check 24` in your existing history maps to
  `[ext:…] 24` by identity, you renumber nothing, and an upstream release that adds a
  check can never force you to.

  Without the label, a bare `Check 24: PASSED` in your gate log — the durable audit
  record — has no referent once core also defines a check 24. That is not a
  hypothetical: it has already happened, and the lead had to disambiguate by hand in
  prose. `scripts/ai-dlc/validate-layer-entries.sh` fails (E6) on a check that redefines a
  core check number with a different title, and `/ai-dlc-update` reports
  `EXTENSION-CHECK-NUMBER-COLLISION` at pull time when an incoming release creates one.
- **`push_candidate: true`** marks a generalizable improvement. `ai-dlc-update`
  drains flagged extensions as the push backlog (spec §8.1) — the pull tool
  produces the push queue as a side effect.
- **Retire on absorption (Rule 27(b)).** When upstream lands your entry's content
  in core, DELETE the entry. `/ai-dlc-update` flags it as
  `EXTENSION-RETIRE-CANDIDATE` (absorbed by this pull) or `EXTENSION-RESTATES-CORE`
  (core already had it at your base — you have been carrying a duplicate for some
  number of releases). Both are title-matched, so they fire **even when upstream
  absorbed your check under a different number** — the case a number-keyed signal
  could never see, and the way two duplicates survived ~35 minor versions unreported.
  Upstream never writes this directory, so it cannot remove the entry for you. An
  absorbed-but-kept extension is the single most common way a layer rots: it starts as
  an exact duplicate and diverges from there.

## Catalog crosswalk table (`kind: check` consumers)

Keep one table here, in this file, mapping every check you have ever numbered to its
label and title. It is the resolver for any `Check N` written in your gate logs,
retros, and escalations **before** you adopted the label — and it is the only sound
one. Do NOT try to resolve those by date: `steps/gate-validation.md` Check 12 mandates
that gate logs are rotated cut-and-paste into archives, so a git date on a rotated line
is the rotation date, not the authorship date.

Seed it from the `EXTENSION-CHECK-NUMBER-COLLISION` and `EXTENSION-RESTATES-CORE` rows
of your next `/ai-dlc-update` report, then freeze it.

**The band is what retires this table.** New checks and rules go at 900 and above
(LC-N5), where core never allocates, so nothing you number from now on can ever need a
crosswalk row. The table stays as the resolver for the numbers you allocated *before*
the band — that history is in your gate logs permanently and no renumber can reach it.
When you renumber an existing check into the band, keep its old row and add the new
number to the `notes` column: the row is what makes a bare `Check 33` in a two-year-old
retro still resolvable. Core does not check this table's completeness and deliberately
does not claim to — it cannot see which numbers you have ever written into evidence, and
a clause core cannot evaluate would be a rule with no mechanism behind it.

| your number | label | title | resolves a bare `Check N` written before | notes |
|---|---|---|---|---|
| 24 | `[ext:gate-validation-domain]` | Financial-display ground-truth live-verify | (label adoption) | collides with core 24 (adversarial convergence), which core added later |

**Validate any entry you author or revise:** `scripts/ai-dlc/validate-layer-entries.sh`.

## Clauses (enforced)

Every clause below is declared in `layer-contract.yaml`, bound to the enforcer that fires on it,
and joined to this file by invariants I36-I38 — a clause with no live enforcer fails the
distribution build, as does an enforcer status no clause claims. The prose above is the
rationale; these are the rules. **ERROR** blocks (a non-zero validator exit, or a `HARD-` status
that stops `apply`); **WARN** reports and never blocks, because a linter that errors dozens of
times on first contact gets disabled and then catches nothing.

- **[LC-E1]** ERROR — an extension declares `kind:`, `hooks:` and `id:`.
- **[LC-E2]** ERROR — the file named by `hooks:` exists in core, resolved by the `core/`-relative
  convention: `team-roles/<role>.md` resolves OUTSIDE this skill directory.
- **[LC-E3]** WARN — a `hooks:` target absent from the incoming ref is reported; the entry hooks
  onto nothing.
- **[LC-E4]** WARN — when the hooked core file changes, the entry is re-read and its verdict
  recorded as still-additive, contradicts-core, or retire. That re-read is the ONLY mechanism
  behind the additive-only rule; skipped, the rule is unenforced.
- **[LC-E5]** WARN — an extension does not restate a core section. A duplicate predating the
  entry's own base has been shipping unreported for some number of releases; retire it, or refile
  it as an override with a `base_sha` if it hardens core.
- **[LC-E6]** WARN — when upstream absorbs an entry's content, DELETE the entry. Matched by title,
  so absorption under a different number is still caught. Upstream never writes this directory, so
  it cannot remove the entry for you, and an absorbed-but-kept extension is the single most common
  way a layer rots.
- **[LC-E7]** WARN — a declared `fixtures:` value names a directory that exists in your tree. The
  binding is what puts your check's fixture into core H1's derived set, so a dangling one makes H1
  report coverage that does not exist.
- **[LC-E8]** WARN — a closed enumeration of what core accepts is a RESTRICTION, not an addition,
  and belongs in `overrides/` with a `base_sha`. Filed here it carries no drift anchor, so when
  core grows a third valid value your entry silently starts contradicting it.
- **[LC-E9]** ERROR — an extension declares `push_candidate:` as `true` or `false`. It is the flag
  the push queue is drained from, so an entry without it can never be offered upstream and never
  retired on absorption.
- **[LC-E10]** ERROR — `kind:` is one of `check`, `step-domain`, `role`, `qualifier`. The Rule 27
  loader routes an entry by its kind, so an unrecognised one — a typo included — is read by
  nothing: the entry sits here looking active and governs no run.
- **[LC-E11]** ERROR — an `extends:` value names exactly one anchor, in the file this entry hooks,
  and that anchor resolves to a heading by the FORWARD containment arm. One anchor, because the
  key exists to give the entry ONE drift subject. Forward, because a reverse-only match (your
  anchor CONTAINS the heading) silently widens the span to that whole section, and you would read
  a narrowed drift row while the classifier watched everything under the heading.
- **[LC-E12]** ERROR — a `kind: qualifier` entry declares both `extends:` and `position:`, and no
  other kind declares `position:`. A qualifier renders inside a core section: without the anchor
  there is nothing to render into, and on any other kind the key states a placement no loader
  performs.
- **[LC-E13]** ERROR — `position:` is `append` or `prepend`. Two positions is the whole vocabulary
  on purpose; a literal-prose anchor would be a third anchor resolver, and `reconcile/lib.sh`
  records two shipped defects caused by duplicate resolvers.
- **[LC-E14]** WARN — when a declared `extends:` span changes, the entry is re-read against the new
  core text. This is LC-E4's duty at the grain you declared instead of at file grain, with the same
  verdict set.
- **[LC-E15]** WARN — an `extends:` anchor that resolves to no heading in the incoming ref is
  reported: upstream renamed the section or absorbed it away. Loud on purpose. A span that resolves
  to nothing compares empty against empty, so an unreported one would answer *clean* for every
  future change to a section your entry still claims to augment — the narrowing turning a true loud
  report into a false quiet one. Re-anchor it, or retire the entry.
- **[LC-N1]** ERROR — a consumer check does not redefine a core check NUMBER under a different
  title. The integer renders into the same merged list as core's, so a bare `Check N` in the gate
  log — the durable audit record — would have two referents.
- **[LC-N2]** WARN — a consumer entry does not define a section number its hooked core file also
  defines.
- **[LC-N3]** WARN — a consumer entry does not define a RULE number its hooked core file also
  defines under a different title. Exactly LC-N1's defect one namespace over.
- **[LC-N4]** WARN — an incoming release that creates a check-number collision is reported and you
  relabel your own catalog. Report-only by design: you must never be unable to take a security fix
  because your catalog needs relabelling.
- **[LC-N5]** WARN — allocate your own check and rule numbers from the reserved band at **900 and
  above**; core allocates below it. LC-N1..LC-N4 are collision DETECTORS: they join your number
  against the numbers core defines *today*, so a number core has not reached yet matches nothing
  and reports clean — until the release where core allocates it, and then the collision appears
  retroactively across every gate log, retro and escalation already written against it. The band
  makes that state unrepresentable where a detector could not see it at all. Bare integers only: a
  suffixed id (`19b`, `4a-bis`) marks a position beside core's number, and an alphabetic id (`AP`)
  has no ordering in a numeric band. A number core *already* defines is LC-N1..LC-N3's subject, not
  this one — an entry deliberately qualifying core's Rule 13 shares that integer *because* the
  integer is its reference, and must never be renumbered. Check numbers are scoped to
  `kind: check`, exactly as LC-N1 is: a step number is a position in an ordered procedure, not an
  allocation from a namespace. The remedy is a renumber plus a crosswalk row — **not** a catalog
  label, which resolves a collision that exists rather than preventing one that does not yet.
- **[LC-R1]** WARN — a `Step <n>` reference in a layer entry resolves to an anchor defined
  somewhere in the rendered rulebook: core plus your own layers.

## Authoring routing (§7.1 — enforced)

The retro / rule-authoring loop MUST route a *new consumer-specific rule* here,
never into a core file. A sprint diff that edits a core-manifest file without a
matching `overrides/` entry FAILS the gate-validation **Core-layer immutability**
check. See `rule-authoring.md`.
