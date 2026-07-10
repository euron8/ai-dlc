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
```

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
- **`push_candidate: true`** marks a generalizable improvement. `ai-dlc-update`
  drains flagged extensions as the push backlog (spec §8.1) — the pull tool
  produces the push queue as a side effect.
- **Retire on absorption (Rule 27(b)).** When upstream lands your entry's content
  in core, DELETE the entry. `/ai-dlc-update` flags it as
  `EXTENSION-RETIRE-CANDIDATE`; upstream never writes this directory, so it cannot
  remove it for you. An absorbed-but-kept extension is the single most common way a
  layer rots: it starts as an exact duplicate and diverges from there.

**Validate any entry you author or revise:** `scripts/validate-layer-entries.sh`.

## Authoring routing (§7.1 — enforced)

The retro / rule-authoring loop MUST route a *new consumer-specific rule* here,
never into a core file. A sprint diff that edits a core-manifest file without a
matching `overrides/` entry FAILS the gate-validation **Core-layer immutability**
check. See `steps/rule-authoring.md`.
