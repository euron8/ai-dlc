<!-- CORE_MANIFEST v1 -->
# Core manifest — the upstream-owned rulebook file set

This file is the single source of truth for the **core** layer (Rule 27):
the upstream-owned files `/ai-dlc-update` overwrites wholesale and that a
consumer MUST NOT edit in place. The gate-validation **Core-layer
immutability** check and Rule 27 both read this list rather than
enumerating it inline, so the set is defined in exactly one place on the
pipeline side.

Paths are relative to the ai-dlc skill directory
(`.claude/skills/ai-dlc/` in a consumer, `core/skills/ai-dlc/` upstream),
except `team-roles/*.md`, which resolves to `.claude/team-roles/*.md`
(outside the skill dir).

```yaml
core_manifest:
  - SKILL.md
  - steps/*.md
  - escalations.md
  - rule-authoring.md
  - team-roles/*.md
```

**Note on the second copy.** `ai-dlc-update`'s
`reconcile/setup-sites.md` carries its own duplicate of this list by
design — a HARD CONSTRAINT keeps that skill self-contained and forbids it
from reading pipeline files. The two lists MUST be kept in sync when the
core file set changes; they are the only two authoritative copies.
