---
name: ai-dlc-update
description: "Reconcile upstream AI/DLC distribution changes into a diverged consumer project via a base-aware semantic three-way merge (the distribution→consumer pull path). Run bare for a dry-run report, or with `apply` to reconcile after review. Use when the user says \"ai-dlc-update\", \"pull upstream\", \"update ai-dlc\", or \"reconcile with distribution\"."
effort: high
---

# AI/DLC Update — the distribution→consumer pull path

You are the AI/DLC **update** orchestrator. Your job is to bring upstream
distribution changes into THIS consumer project **without destroying the
consumer's divergence** — a base-aware semantic three-way merge, not the
blunt overwrite `install.sh` performs.

This is the third skill of the lifecycle triad: **setup** (onboard) ·
**ai-dlc** (operate) · **update** (reconcile). It runs on the consumer side
because it writes the consumer.

## HARD CONSTRAINT — self-contained

This skill and its reconcile engine MUST be self-contained. They read ONLY:
- their own files under `.claude/skills/ai-dlc-update/`,
- `git` (shelled out),
- the consumer's `.ai-dlc-version` stamp.

They MUST NOT read or depend on the consumer's PIPELINE rulebook
(`.claude/skills/ai-dlc/SKILL.md`, `steps/*.md`, `team-roles/*.md`). This is
what makes the bootstrap drop-in (§6.2 of the design spec) safe at ANY
divergence: a net-new directory that collides with nothing and needs nothing.
If you ever feel the urge to read a pipeline step to "understand the rules",
STOP — you don't; you diff text and classify it.

## The three inputs (three-way merge)

- **base**  = distribution `core/` at the sha recorded in the consumer's
  stamp (`.claude/.ai-dlc-version`, format `X.Y.Z @ <sha>`). The last upstream
  content this consumer received.
- **theirs** = distribution `core/` at the target ref (default upstream HEAD).
- **ours**  = the consumer's live tree (`.claude/…`, plus `scripts/` for
  `core/scripts/…`).

`base` and `theirs` are fetched from the distribution git repo. `ours` is the
working tree. See §6.1 of the design record — this is a vendored-dep updater
(`npm update` runs in your project and reaches the registry), not the reverse.

## Path mapping (core/ → consumer)

- `core/scripts/<x>`  →  `scripts/<x>`   (project root)
- `core/<x>`          →  `.claude/<x>`   (everything else: skills, team-roles,
  hooks, session-driver)

## Divergence taxonomy — the classifier's output buckets

Every consumer block that differs from upstream is one of:

| Bucket | Meaning | Pull action |
|--------|---------|-------------|
| **rewording** | same concept, different prose; already-upstream in substance | take theirs (drop the consumer rewording) |
| **domain-local** | consumer machinery upstream intentionally lacks | keep ours; layer theirs' non-conflicting additions around it |
| **un-pushed-innovation** | generalizable improvement not yet absorbed upstream | keep ours; **flag for push** (feeds the absorption arc) |
| **conflict** | both changed the same core rule incompatibly | operator adjudicates |

## Procedure

1. **Resolve inputs.** Read the stamp → `base` sha. Resolve `theirs` (arg or
   upstream HEAD). Confirm the distribution repo is reachable (a configured
   upstream path/remote — until the stamp carries a URL, ask the operator for
   the distribution checkout path).
2. **Mechanical pre-classification** (cheap, deterministic — no agents):
   run `reconcile/preclassify.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>`.
   It hashes base/theirs/ours per changed file and buckets each into:
   - `UPSTREAM-ONLY-ADD` (net-new upstream, consumer lacks it) → **apply (pure)**
   - `UPSTREAM-ONLY` (upstream changed, consumer untouched vs base) → **apply**
   - `ALREADY-AT-THEIRS` / `ALREADY-PRESENT` → **noop**
   - `BOTH-CHANGED` / `BOTH-ADDED` / `UPSTREAM-MOD+consumer-deleted` → **needs semantic classify**
3. **Semantic per-block classify** — for every file the pre-pass marked
   `…CLASSIFY`, dispatch ONE generic agent per file (batch trivial single-block
   diffs) using `reconcile/classify-block.md` as the prompt. Block granularity
   = per-file + per-numbered-item (rule / `###` section / check). Each agent
   computes the file's own base/theirs/ours three-way with git and returns
   structured per-block buckets. Agents return DATA (bucket tallies + only the
   conflict/flag details), never echoed file content — keeps the orchestrator
   context clean.
4. **Emit the dry-run report FIRST** — `_bmad-output/ai-dlc-update/reconcile-report.md`:
   per-file + per-block bucket, proposed action, the push-candidate list, and
   the conflict list for operator review. **Stop here unless invoked with `apply`.**
5. **Apply (only on `apply` + operator confirm of the conflict list):**
   - apply-bucket blocks → write theirs into ours (path-mapped).
   - keep/domain-local/innovation blocks → leave ours; for domain-local, layer
     theirs' non-conflicting additions; for innovation, append to the
     push-candidate ledger.
   - conflicts → apply only operator-adjudicated resolutions.
   - Self-update last: treat this skill's own files as apply-safe and apply any
     new version of `ai-dlc-update` at the end (or re-exec).
   - Re-stamp `.claude/.ai-dlc-version` = `<theirs-version> @ <theirs-sha>` and
     write `_bmad-output/ai-dlc-update/reconcile-log-<ts>.md`.
6. **Safety.** The consumer's `docs/pre-ai-dlc/<ts>/_divergence/` archive
   (written by install) plus the dry-run report give a full recover path.
   Nothing is destroyed without an operator confirm.

## Shared engine, thin orchestrator

The per-block classifier (`reconcile/classify-block.md`) is a SHARED engine
that serves four jobs (design §8): pull-reconcile (this skill), push-mine,
Phase-2 untangle, and N→1 fan-in dedupe. `ai-dlc-update` is only the **pull
entry point** that calls it — it does not own it. Keep the classifier prompt
free of pull-only assumptions so the other three jobs can reuse it.

## Not yet wired (design §6.1 gaps — call out, don't silently skip)

- **Upstream URL not in the stamp.** Until `.ai-dlc-version` carries the
  distribution ref, the operator supplies the distribution checkout path.
- **Self-update apply-order** is handled in step 5 (apply own files last).
