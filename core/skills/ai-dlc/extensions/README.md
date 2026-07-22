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
  core `known_skills` list (`schemas/provenance-block.json`), so a provenance block naming your
  skill passes **without editing the core schema**. Either shape:

  ```json
  { "known_skills": ["bmad-agent-tea-tea"] }
  ```

  Additive and deduped; a present-but-malformed file fails the gate **closed** (a broken layer
  file must never silently degrade to the core-only list). This is the layer-correct alternative to
  adding a skill name to the core schema in place — which `/ai-dlc-update` flags as
  `HARD-UNREGISTERED-CORE-DRIFT` (schemas are drift-scanned as of v0.63.2).

## Entry contract

Each entry is a markdown file that declares, in frontmatter, where it hooks into
the pipeline so the layer loader (SKILL.md Rule 27) can activate it:

```markdown
---
kind: check | step-domain | role
hooks: steps/gate-validation.md        # the core file/step this augments
id: <stable-id>                        # e.g. exec-health-floor, check-financial-display
push_candidate: false                  # true = generalizable; feeds the ai-dlc-update push-mine / absorption arc
---

<the additive rule / check / step body>
```

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

- **Additive only.** An extension ADDS behavior; it never edits a core rule. To
  *change* an existing core rule, use `overrides/` instead.
  - **A restriction is not an addition.** "Only X and Y are valid", "Z is NOT
    subject to", any closed enumeration of what core accepts — these *narrow* a
    core rule and belong in `overrides/` with a `base_sha`. Filed here they carry
    no drift anchor, so when core grows a third valid value your entry silently
    starts contradicting it.
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
    core's section; there is no grain for that today (`overrides/` gets you there
    only by replacing the whole section verbatim, and then you carry `base_sha`
    drift on prose you never meant to change). If that placement matters for your
    entry, raise it upstream as a push candidate rather than reaching for an
    override.
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
  prose. `scripts/validate-layer-entries.sh` fails (E6) on a check that redefines a
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
of your next `/ai-dlc-update` report, then freeze it:

| your number | label | title | resolves a bare `Check N` written before | notes |
|---|---|---|---|---|
| 24 | `[ext:gate-validation-domain]` | Financial-display ground-truth live-verify | (label adoption) | collides with core 24 (adversarial convergence), added upstream in v0.48.0 |

**Validate any entry you author or revise:** `scripts/validate-layer-entries.sh`.

## Authoring routing (§7.1 — enforced)

The retro / rule-authoring loop MUST route a *new consumer-specific rule* here,
never into a core file. A sprint diff that edits a core-manifest file without a
matching `overrides/` entry FAILS the gate-validation **Core-layer immutability**
check. See `rule-authoring.md`.
