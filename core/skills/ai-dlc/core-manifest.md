<!-- CORE_MANIFEST v1 -->
# Core manifest — the upstream-owned file set

This file is the single source of truth for the **core** layer (Rule 27):
the upstream-owned files `/ai-dlc-update` overwrites wholesale and that a
consumer MUST NOT edit in place. The gate-validation **Core-layer
immutability** check, the edit-time `ai-dlc-core-guard.sh` hook, and Rule 27
all read this list rather than enumerating it inline, so the set is defined
in exactly one place on the pipeline side.

Most entries are **rulebook prose** — a change to one goes into a consumer
layer (`overrides/` to shadow a rule, `extensions/` to add one). `hooks/ai-dlc-*.sh`
are the exception: they are **machinery, not rulebook, and have no layer
grain**. A hook is upstream-owned like the rest, but a consumer that needs
different hook behavior configures it through the hook's declared `AI_DLC_*`
tunables or takes the change upstream — there is no `overrides/` or
`extensions/` entry for a hook. The core-guard routes accordingly.

**Only the `ai-dlc-*` hooks are core.** The glob is `hooks/ai-dlc-*.sh`, not
`hooks/*.sh`, because a consumer may ship its OWN hooks alongside the core set
(e.g. a `guarded-merge.sh`). Those are consumer-owned — the guard must NOT deny
an edit to them and the immutability check must NOT flag them. Every hook
`/ai-dlc-update` ships carries the `ai-dlc-` prefix; the prefix is the boundary.

Paths are relative to the ai-dlc skill directory
(`.claude/skills/ai-dlc/` in a consumer, `core/skills/ai-dlc/` upstream),
except `team-roles/*.md` and `hooks/ai-dlc-*.sh`, which resolve to
`.claude/team-roles/*.md` and `.claude/hooks/ai-dlc-*.sh` (outside the skill dir).

```yaml
core_manifest:
  - SKILL.md
  - steps/*.md
  - escalations.md
  - rule-authoring.md
  - team-roles/*.md
  - hooks/ai-dlc-*.sh
```

**Note on the second copy.** `ai-dlc-update`'s
`reconcile/setup-sites.md` carries its own duplicate of this list by
design — a HARD CONSTRAINT keeps that skill self-contained and forbids it
from reading pipeline files. The two lists MUST be kept in sync when the
core file set changes; they are the only two authoritative copies.
