### Rule 27 -- Layered rulebook: core, extensions, overrides

This file is the full text of Rule 27 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

The consumer rulebook is three layers. This rule is how a consumer
self-improves *without* re-tangling core against upstream (spec §7).

The clauses a layer entry must hold are declared in `layer-contract.yaml`
(alongside this file), each bound to the enforcer that fires on it. Read it
for the enforced set; the two layer `README.md` files carry the same clause
ids with the rationale, at the same severity — bound by I61.

Every entry declares `conforms_to: <n>`, the contract version it has been
migrated to (**ERROR**, E17). It is a receipt and not an exemption: declaring
a lower version subtracts no clause, it only lets the validator name which
clauses postdate your last migration [LC-C1, LC-C2].

**core** -- the upstream-owned file set declared in `core-manifest.md`
(alongside this file). For a per-path answer, run
`scripts/ai-dlc/core-paths.sh --is-core <path>` rather than matching globs by
eye; it is the same derivation the edit-time guard uses, and a list restated
anywhere else rots against the manifest silently.
`/ai-dlc-update` overwrites these wholesale. You MUST NOT edit a core file
in place (enforced at the keystroke by `ai-dlc-core-guard.sh` and at the
gate by **Core-layer immutability**). The rulebook files route to a layer;
`hooks/ai-dlc-*.sh` are machinery with no layer grain — a hook change goes
upstream or through its declared `AI_DLC_*` tunables, never into `overrides/`.
Only the `ai-dlc-*` hooks are core; a consumer's own hooks are not.

**extensions** (`{skill}/extensions/`) -- consumer-owned, additive: net-new
rules, gate-checks, and domain step logic upstream does not carry. Upstream
never writes here.

**overrides** (`{skill}/overrides/`) -- consumer-owned entries that SHADOW a
specific core rule/check by id (the settings.json-upsert pattern). Upstream
never writes here.

**Loading (a Read tool call per Rule 21, at INITIALIZATION, after core is
loaded):** if `extensions/` exists and is non-empty, Read its entries and treat
them as additional active rules/checks/steps; if `overrides/` exists, Read each
entry and let it shadow the named core rule/check for this run. **Precedence:
overrides > extensions > core.** Absent or empty layers = pure core, identical
to a fresh install. See `extensions/README.md` and `overrides/README.md` for the
entry contracts. An entry's `hooks:`/`shadows:`/`extends:` path is `core/`-relative:
`steps/<x>.md` and `SKILL.md` live under this skill dir, but `team-roles/<role>.md`
resolves to `.claude/team-roles/<role>.md` (outside the skill dir) — map it the
same way, not skill-relative.

An extension entry whose `kind:` is **`qualifier`** does not render as its own
section. It renders INSIDE the core section its `extends: <file>#<anchor>` names,
at the end of that section for `position: append` or immediately after the heading
for `position: prepend`, and it qualifies core's prose there rather than replacing
it. Core's text in that section stays in force — a qualifier adds, it never
deletes; an entry that needs to change what core says is an override. The other
kinds (`check`, `step-domain`, `role`) render as their own sections, as before.

**(a) `base_sha` provenance (normative).** An override's `base_sha` MUST be the
**distribution** sha of the core rule when the override was authored. A value that
resolves in the *consumer's own* repo is invalid: `/ai-dlc-update` computes drift
with `git diff <base_sha>..<theirs>` inside the distribution checkout, so a
consumer sha makes that diff impossible and drift detection silently dies for
that entry. `scripts/ai-dlc/validate-layer-entries.sh` fails on it (a correct base_sha
never resolves in the consumer repo); `reconcile/layer-drift.sh` reports it as
HARD and blocks `apply` until the operator adjudicates. Re-stamp `base_sha`
whenever you revise an override.

**(b) Retirement duty on absorption [LC-E6].** When upstream lands a layer entry's content
in core, the consumer MUST retire that entry. An absorbed extension left in place
becomes a duplicate that silently forks from the core text it once matched, and
then contradicts it. `/ai-dlc-update` emits
`EXTENSION-RETIRE-CANDIDATE` as the signal; retirement is an operator-gated delete
-- upstream never writes the layer, so it cannot remove the entry for you.

**(c) Additive means additive.** An extension MUST NOT restate or restrict a core
section. Restating forks the prose and rots (the copy cannot drift-check against
the original). Restricting a core rule -- "only X and Y are valid", "Z is NOT
subject to" -- is an **override wearing extension frontmatter**: file it in
`overrides/` with a `base_sha` so drift is tracked. Extensions carry `hooks:` only,
which is a file-grain anchor, so a restriction hidden in one is invisible to every
check the pull performs.

**(d) An extension's numbered sections are ITS OWN catalog -- label them [LC-N1, LC-N4].**
Because
extensions are additive, an extension's `### 24.` and core's `### 24.` render into ONE
merged list under ONE integer. The number stops being a referent, and the lead then
writes that number into the gate log, where the ambiguity becomes permanent. So a
check defined in `extensions/checks/` belongs to **that file's** catalog, keyed by its
`id:` frontmatter, and its heading carries the label: `### 24. [ext:<id>] <title>`
(core's carries `[core]`). The integer is never changed -- the label is *added* -- so
history maps by identity and no consumer renumbers on an upstream release. Loading is
what binds the catalog: a check read from `extensions/checks/` is that file's check
**however its heading is written**, so an un-migrated consumer is correct, just not yet
legible. Enforced by `scripts/ai-dlc/validate-layer-entries.sh` (E6) and, at pull time, by
`EXTENSION-CHECK-NUMBER-COLLISION` in the reconcile report. Full convention:
`steps/gate-validation.md`, "Consumer-catalog crosswalk".

This binds every numbered section an extension defines, not only checks [LC-N3]. An extension's
`## Rule <n>` and core's `### Rule <n>` render into one merged rulebook under one integer,
and "Rule 29" in a gate log, retro finding or dispatch brief then has two referents. Label
it the same way, before the separator: `## Rule <n> [ext:<id>] -- <title>`. The integer never
moves. Reported by `validate-layer-entries.sh` (W4) as a WARN, never an ERROR -- a consumer
must not be unable to take a fix because its own rule catalog needs relabelling -- and
written by `reconcile/relabel-extension-checks.sh --apply`.

Allocate EVERY consumer id from **900 and above**, or from the reserved **`X` prefix** if it
is alphabetic; core allocates below the floor and never at that prefix. The partition is
**total** — bare integers, suffixed ids (`19b` -> `919b`, `0b` -> `900b`), alphabetic ids
(`AP` -> `XAP`) and step ids alike, in every namespace and every `kind:`. Your numeric prefix
carries your ordering, so moving your whole range preserves every position within it; what
you lose is sorting a section beside a CORE section of the same number, and if that is what
an entry needs it is `kind: qualifier` with `extends:`, which renders it inside the core
section and borrows no id at all. A label resolves a collision that already exists; the band
prevents one that does not yet. An **ERROR** from `validate-layer-entries.sh` (E15), so the
pre-push refuses until you migrate; core is held to both halves of the complement by I45. An
id you RETIRE by migrating needs a crosswalk row (E16). Convention and the crosswalk:
`extensions/README.md` [LC-N5, LC-N6].

**Minimum mechanism (Rule 26(c)).** Failure caught: in-place rule authoring
silently mutating core, so the next upstream pull clobbers the new rule or
false-conflicts against it; and, per
(a)-(c), a consumer layer silently shadowing, duplicating, or contradicting a core
rule upstream has since changed. False positive: one override declaration when a
consumer genuinely must change a core rule; one operator re-confirmation per
still-valid override whose core section moved. Removal condition: retire once core
ships as an immutable package the skill loads rather than a writable tree, with
layer bindings resolved (and validated) at load time.
