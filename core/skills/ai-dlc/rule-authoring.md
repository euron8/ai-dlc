# Rule-Authoring Style Guide

Referenced by SKILL.md Rule 18 and the retro rule-file audit (`retro.md`
Step 4). READ AND FOLLOW when authoring or auditing a rule in this skill,
CLAUDE.md, `docs/coding-conventions.md`, step files, or team role files.

**Style:**
- State mandates with imperative voice ("Do X", "Never Y") or MUST /
  MUST NOT / SHALL. Forbidden: "should", "try to", "consider",
  "prefer", "in most cases", and any other language that can be read
  as optional when the intent is a mandate. "May" is allowed only
  when granting permission or autonomy, not when stating a mandate.
- State the enforcement consequence inline when one applies:
  "Violation fails gate N" or "Missing = Critical severity".
- No sprint or story references.
- No incident descriptions or "because we got burned" narrative.
- No parenthetical origin notes after a directive.
- No embedded dates, retro quotes, or escalation quotes.

**Layer routing (Rule 27 / §7.1 — MANDATORY on a layered consumer).** Before
writing an authored rule, route it by kind — never edit a core-manifest file in
place:
- **New consumer-specific rule or check** → `{skill}/extensions/` (with the
  `extensions/README.md` frontmatter contract). Never core.
- **Change to an existing core rule** → an `{skill}/overrides/` entry that
  shadows it by id (with `shadows:` + `base_sha:`). Never an in-place core edit.
- **Generalizable improvement** → `{skill}/extensions/` AND set
  `push_candidate: true`, which feeds the `ai-dlc-update` push-mine (spec §8.1).
An in-place edit of a core file fails the gate-validation **Core-layer
immutability** check. On a pre-Phase-2 consumer (no layer directories) or the
distribution source itself, this routing is dormant and rules are authored in
place as before.

**Routing traps (Rule 27(a)-(c)) — check before you file:**
- A rule that says "only X and Y are valid" or "Z is NOT subject to" **restricts**
  core. That is an override, not an extension, no matter how it is worded. Filed as
  an extension it carries no `base_sha`, so nothing ever notices when the core rule
  it restricts moves underneath it.
- An extension MUST NOT restate a core section (same heading, or same step number
  with the same title). The copy forks at authoring time and rots silently; a
  "Step 5c" reference then resolves to two different sections.
- An override's `base_sha` is a **distribution** sha, not one from this repo. A sha
  that resolves in *this* repo is always wrong and silently disables drift
  detection for that entry — the pull diffs it inside the distribution checkout.

**Validate after authoring or revising any layer entry:**
`scripts/validate-layer-entries.sh` (errors on a poisoned `base_sha` or a broken
`hooks:`/`shadows:` target; warns on restatement, restriction, and dangling step
pointers). Run it before committing the entry.

**Scope.** Rule files only: this skill, CLAUDE.md,
coding-conventions.md, step files, team role files. Planning
artifacts (PRDs, stories, reviews, retros) and export bundles are
different formats.

**Cleanup.** The retro's rule file audit (`retro.md` Step 4) scans
rule files each sprint for three classes of violation: **narrative
drift** (rule text gained origin context), **rule weakness** (rule
text became readable as optional), and **complexity accretion**
(machinery lacking the Rule 26(c) contract, or with false positives
and no true catches). All are cleanup targets.
