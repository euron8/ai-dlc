<!-- CORE_MANIFEST v1 -->
# Core manifest — the upstream-owned file set

This file is the single source of truth for the **core** layer (Rule 27):
the upstream-owned files `/ai-dlc-update` overwrites wholesale and that a
consumer MUST NOT edit in place. The gate-validation **Core-layer
immutability** check, the edit-time `ai-dlc-core-guard.sh` hook, and Rule 27
all read this list rather than enumerating it inline, so the set is defined
in exactly one place on the pipeline side.

Most entries are **rulebook prose** — a change to one goes into a consumer
layer (`overrides/` to shadow a rule, `extensions/` to add one). The
**machinery** entries are the exception: `hooks/ai-dlc-*.sh`,
`scripts/ai-dlc/*`, `session-driver/*.sh`, `schemas/*.json`, and the
`skills/ai-dlc-setup/**` and `skills/ai-dlc-update/**` subtrees have **no layer
grain**. They are upstream-owned like the rest, but a consumer that needs
different behavior configures it through the declared `AI_DLC_*` tunables or
takes the change upstream — there is no `overrides/` or `extensions/` entry for
a hook, a validator, a schema, or the update engine. The core-guard routes
accordingly.

**The machinery subtrees were claimed late, and the gap had teeth.** Until
v0.157.0 this list stopped at the `ai-dlc` skill dir, so five subtrees
`install.sh` overwrites wholesale carried **no edit-time protection at all** —
the same hole I12 records for `ai-dlc-setup/` (v0.63.0) and `schemas/`, found
each time only when a real pull hit it. It also read the other way: Check 16's
stub audit asks this list whether a marker sits in an upstream-owned file, and
because `skills/ai-dlc-update/**` was unclaimed, a prose comment in
`reconcile/apply.sh` was audited as consumer-authored and failed a consumer's
§6 gate four times with no clearing path — a core file cannot carry a consumer
backlog item, and the guard denies the edit that would add one.

**The validators are enumerated; everything else is a glob.** A glob names our
set only where the directory is exclusively ours, and `scripts/` is shared — a
consumer's own audit scripts sit beside ours under no distinguishing prefix. Core
scripts therefore have a directory of their own, `scripts/ai-dlc/`, and the
manifest enumerates its contents. **The enumeration and the directory are each
other's check:** `validate-enforcement-map.sh` asserts the list below equals
`core/scripts/` exactly, so a validator added upstream without a manifest entry
fails the distribution's own gate, and a file appearing in a consumer's
`scripts/ai-dlc/` that is not on the list is a consumer script in the core
directory. Neither side is hand-maintained alone.

**Consumer-authored ai-dlc scripts do not belong there.** A consumer's own
pipeline tooling — snapshot resets, dormant-gate audits, sprint-entry sweeps —
goes in `scripts/ai-dlc-local/`, which core never reads, never writes and never
overwrites. The two directories differ by ownership, not by subject.

**Only the `ai-dlc-*` hooks are core.** The glob is `hooks/ai-dlc-*.sh`, not
`hooks/*.sh`: a consumer may ship its OWN hooks alongside the core set. Those are
consumer-owned — the guard MUST NOT deny an edit to them and the immutability
check MUST NOT flag them. Every hook `/ai-dlc-update` ships carries the
`ai-dlc-` prefix; the prefix is the boundary.

Paths are relative to the ai-dlc skill directory
(`.claude/skills/ai-dlc/` in a consumer, `core/skills/ai-dlc/` upstream),
except these prefixes, which resolve outside it:

| entry prefix       | consumer path                    |
|--------------------|----------------------------------|
| `team-roles/`      | `.claude/team-roles/`            |
| `hooks/`           | `.claude/hooks/`                 |
| `session-driver/`  | `.claude/session-driver/`        |
| `schemas/`         | `.claude/schemas/`               |
| `skills/`          | `.claude/skills/`                |
| `scripts/`         | `scripts/` (project root)        |

`to_consumer_glob()` is the one implementation of that mapping. It lives in
`hooks/ai-dlc-core-guard.sh` (edit-time) and `scripts/ai-dlc/core-paths.sh`
(everything else, including Check 16's scope filter), byte-identical by
assertion — `validate-enforcement-map.sh` I25 fails the build if they fork,
because a mapping that differs between them lets the gate exempt what the guard
protects.

```yaml
core_manifest:
  - SKILL.md
  - steps/*.md
  - escalations.md
  - rule-authoring.md
  - templates/*.md
  - team-roles/*.md
  - hooks/ai-dlc-*.sh
  - session-driver/*.sh
  - schemas/*.json
  - skills/ai-dlc-setup/**
  - skills/ai-dlc-update/**
  - scripts/ai-dlc/audit-rule-files.sh
  - scripts/ai-dlc/core-paths.sh
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
