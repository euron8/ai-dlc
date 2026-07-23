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
and `scripts/ai-dlc/*` are the exception: they are **machinery, not rulebook,
and have no layer grain**. They are upstream-owned like the rest, but a
consumer that needs different behavior configures it through the declared
`AI_DLC_*` tunables or takes the change upstream — there is no `overrides/` or
`extensions/` entry for a hook or a validator. The core-guard routes accordingly.

**Why the validators are enumerated and the rest are globs.** A glob works when
the directory is exclusively ours. `scripts/` never was: in the reference consumer
it holds 103 files of which 25 are core, and no prefix separates them — ai-dlc
ships `audit-rule-files.sh` while the consumer owns `audit-dormant-gates.sh`,
`audit-main-since.sh` and `audit-rule-exercise.sh`. No glob over that directory can
name our set without also naming theirs, which is the same trap `hooks/*.sh` hit
before it was narrowed to `hooks/ai-dlc-*.sh`.

So core scripts were given a directory of their own (`scripts/ai-dlc/`, as of
v0.126.0) and the manifest enumerates its contents. **The enumeration and the
directory are each other's check:** `validate-enforcement-map.sh` asserts the list
below equals `core/scripts/` exactly, so a validator added upstream without a
manifest entry fails the distribution's own gate, and a file appearing in a
consumer's `scripts/ai-dlc/` that is not on the list is a consumer script in the
core directory. Neither can drift silently, and neither is hand-maintained alone.

**Consumer-authored ai-dlc scripts do not belong there.** A consumer's own
pipeline tooling — snapshot resets, dormant-gate audits, sprint-entry sweeps —
goes in `scripts/ai-dlc-local/`, which core never reads, never writes and never
overwrites. The two directories differ by ownership, not by subject.

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
  - scripts/ai-dlc/audit-rule-files.sh
  - scripts/ai-dlc/gen-architecture-index.js
  - scripts/ai-dlc/sprint-status.sh
  - scripts/ai-dlc/stamp-story-provenance.sh
  - scripts/ai-dlc/sync-taught-schema.sh
  - scripts/ai-dlc/validate-adversarial-convergence.sh
  - scripts/ai-dlc/validate-artifact-budget.sh
  - scripts/ai-dlc/validate-audit-anchors.sh
  - scripts/ai-dlc/validate-ci-gates.sh
  - scripts/ai-dlc/validate-compact-window.sh
  - scripts/ai-dlc/validate-cycle-commits.sh
  - scripts/ai-dlc/validate-draft-stamps.sh
  - scripts/ai-dlc/validate-escalation-resolution.sh
  - scripts/ai-dlc/validate-escalation-status-vocabulary.sh
  - scripts/ai-dlc/validate-gate-adjudication.sh
  - scripts/ai-dlc/validate-gate-manifest.sh
  - scripts/ai-dlc/validate-h2-attestation.sh
  - scripts/ai-dlc/validate-layer-entries.sh
  - scripts/ai-dlc/validate-locked-anchor.sh
  - scripts/ai-dlc/validate-mandatory-rules.sh
  - scripts/ai-dlc/validate-provenance-block.sh
  - scripts/ai-dlc/validate-reattach-budget.sh
  - scripts/ai-dlc/validate-retro-evidence.sh
  - scripts/ai-dlc/validate-steering-budget.sh
  - scripts/ai-dlc/verdict.sh
  - scripts/ai-dlc/wait-for-deliverable.sh
```

**Note on the second copy.** `ai-dlc-update`'s
`reconcile/setup-sites.md` carries its own duplicate of this list by
design — a HARD CONSTRAINT keeps that skill self-contained and forbids it
from reading pipeline files. The two lists MUST be kept in sync when the
core file set changes; they are the only two authoritative copies.
