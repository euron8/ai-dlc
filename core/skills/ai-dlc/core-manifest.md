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

**An unclaimed core subtree fails in both directions.** It carries no edit-time
protection, so a consumer can edit it in place and the next pull either clobbers
the change or raises a false BOTH-CHANGED conflict. And Check 16's stub audit asks
this list whether a marker sits in an upstream-owned file, so an unclaimed core
file is audited as consumer-authored — a bar it can never clear, because a core
file cannot carry a consumer backlog item and the guard denies the edit that would
add one. Every subtree `install.sh` overwrites wholesale MUST appear below.

**Every entry is a glob over a directory that is exclusively ours.** A glob names
our set only where that holds. `scripts/` does not hold it — a consumer's own audit
scripts sit beside ours under no distinguishing prefix — so core scripts have a
directory of their own, `scripts/ai-dlc/`, and the manifest claims all of it. The
same rule governs any new entry: where a directory is shared, give core its own
directory inside it rather than listing the files we own there. Do NOT enumerate
what a glob can name.

**A file in `scripts/ai-dlc/` is core whether or not the distribution ships that
name.** The directory is the boundary, not the file list, so the guard denies an
in-place edit AND denies the `Write` that would create such a file, routing the
author to `scripts/ai-dlc-local/`. `core-script-boundary`'s assertion 8 asserts all
three directions.

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
  - scripts/ai-dlc/*
```

**Note on the second copy.** `ai-dlc-update`'s
`reconcile/setup-sites.md` carries its own duplicate of this list by
design — a HARD CONSTRAINT keeps that skill self-contained and forbids it
from reading pipeline files. The two lists MUST be kept in sync when the
core file set changes; they are the only two authoritative copies.
