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
