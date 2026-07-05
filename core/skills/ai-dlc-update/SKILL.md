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
2. **Self-update — an AUTONOMOUS, self-contained commit→merge cycle (before any
   rulebook classify/apply).** You run FROM a copy of this skill inside the
   consumer; a pull can include a change to that copy, so the logic executing the
   reconcile may be stale relative to `theirs`. The skill's own files
   (`core/skills/ai-dlc-update/**` — SKILL.md + `reconcile/*`) are **upstream-owned
   tooling, overwrite-safe** — the consumer never edits them (like `core`), so
   refreshing them carries no consumer-divergence risk. Therefore the self-update
   lands on its OWN cycle, **autonomously — no operator approval**, distinct from
   the operator-gated rulebook reconcile (step 8).

   Diff `base→theirs` restricted to `core/skills/ai-dlc-update/**`. If EMPTY, say
   so in one line and continue to step 3. If NON-EMPTY:
   - **Run the self-update cycle autonomously:** cut a dedicated branch
     `ai-dlc-update/self-update-<theirs-version>-<ts>`, overwrite the consumer's
     `.claude/skills/ai-dlc-update/**` with `theirs`, commit
     (`chore(ai-dlc-update): self-update <base-ver> → <theirs-ver>`), push, open a
     PR, and **auto-merge (squash, delete branch)** — no operator gate. If there
     is no remote / push fails, commit locally and note it; do not block the run.
   - **Then inform the operator** (report, do not gate): the self-update landed
     (merged PR ref), a one-line summary of what changed (touches `reconcile/` —
     the engine — vs prose/docs), and that the CURRENT invocation is still
     executing the PRE-update logic. Offer the choice: **re-invoke now** so this
     reconcile runs on the new logic (recommended when the change touched
     `reconcile/` or the classify/apply/safety procedure), or **continue** this
     run on the current logic (fine for docs-only changes). Proceeding on
     "continue" is allowed — this is informational, not a blocking gate; the
     self-update itself already landed autonomously.
3. **Mechanical pre-classification** (cheap, deterministic — no agents):
   run `reconcile/preclassify.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>`.
   It hashes base/theirs/ours per changed file and buckets each into:
   - `UPSTREAM-ONLY-ADD` (net-new upstream, consumer lacks it) → **apply (pure)**
   - `UPSTREAM-ONLY` (upstream changed, consumer untouched vs base) → **apply**
   - `ALREADY-AT-THEIRS` / `ALREADY-PRESENT` → **noop**
   - `BOTH-CHANGED` / `BOTH-ADDED` / `UPSTREAM-MOD+consumer-deleted` → **needs semantic classify**
4. **Semantic per-block classify** — for every file the pre-pass marked
   `…CLASSIFY`, dispatch ONE generic agent per file (batch trivial single-block
   diffs) using `reconcile/classify-block.md` as the prompt. Block granularity
   = per-file + per-numbered-item (rule / `###` section / check). Each agent
   computes the file's own base/theirs/ours three-way with git and returns
   structured per-block buckets. Agents return DATA (bucket tallies + only the
   conflict/flag details), never echoed file content — keeps the orchestrator
   context clean.
5. **Emit the dry-run report FIRST** — `_bmad-output/ai-dlc-update/reconcile-report.md`:
   per-file + per-block bucket, proposed action, the push-candidate list, and
   the conflict list for operator review. **Stop here unless invoked with `apply`.**
6. **Isolate — branch before ANY write (apply only, MANDATORY).** The reconcile
   MUST NOT mutate the consumer's live branch in place. Before the first write
   in step 7:
   - Shell to git in the consumer tree. If it is not a git repo, STOP and tell
     the operator (no safe isolation possible).
   - If the working tree has uncommitted changes that would tangle the reconcile
     diff, STOP and report — let the operator stash/commit first. (A dirty tree
     unrelated to the rulebook may be fine; when in doubt, stop.)
   - `git checkout -b ai-dlc-update/<theirs-version>-reconcile-<ts>` off the
     current branch. ALL step-7 writes land here, so the operator reviews a
     clean diff / opens a PR — never a silently-mutated working branch.
   This is a hard requirement, symmetric with the pipeline's own branch-per-unit
   discipline; the `_divergence/` archive (step 9) is a backstop, not a
   substitute for the branch.
7. **Apply (only on `apply` + operator confirm of the conflict list, on the
   step-6 branch):**
   - apply-bucket blocks → write theirs into ours (path-mapped).
   - keep/domain-local/innovation blocks → leave ours; for domain-local, layer
     theirs' non-conflicting additions; for innovation, append to the
     push-candidate ledger.
   - conflicts → apply only operator-adjudicated resolutions.
   - (The skill's OWN files are NOT touched here — they were already refreshed by
     the autonomous self-update cycle in step 2.)
   - Re-stamp `.claude/.ai-dlc-version` = `<theirs-version> @ <theirs-sha>` and
     write `_bmad-output/ai-dlc-update/reconcile-log-<ts>.md`.
8. **Deliver — branch → commit → push → PR → merge.** The reconcile is landed
   through the consumer's normal review flow, never force-written to the working
   branch:
   - **Commit** all step-7 writes on the step-6 reconcile branch, with a subject
     like `chore(ai-dlc-update): reconcile distribution <base-ver> → <theirs-ver>`
     and a body summarizing buckets applied + conflicts adjudicated + the log path.
   - **Push** the reconcile branch to the consumer's remote (`origin`). If there
     is no remote or push fails (a local-only consumer), STOP here and hand the
     operator the local branch + diff to merge manually — do not silently drop
     the work.
   - **Open a PR** into the working branch (`gh pr create`), body = the reconcile
     report summary (buckets, conflicts, push-candidates).
   - **Merge on operator approval.** The PR is the final review gate — merge
     (squash, delete branch) only after the operator approves it. The skill does
     NOT auto-merge without that approval, even though conflicts were already
     confirmed pre-apply. On merge, the re-stamp + log + changes reach the
     working branch through the merge.
   - Drain any `push_candidate`-flagged extensions into the push-candidate ledger
     for a later upstream push-mine (spec §8.1).
9. **Safety.** Three independent recover layers: the step-6 reconcile **branch**
   (the working branch is never touched), the consumer's
   `docs/pre-ai-dlc/<ts>/_divergence/` archive (written by install), and the
   dry-run report. Nothing is destroyed without an operator confirm.

## Layered consumers (Rule 27 / spec §7) — the reconcile shrinks

When the consumer has the Phase 2 layer split (a populated
`{skill}/extensions/` and/or `{skill}/overrides/`), the reconcile surface
collapses:

- **core** (the protected-manifest files) → overwrite from theirs wholesale.
  No per-block classify needed — the consumer never edited core in place (the
  gate-validation Core-layer immutability check guarantees it), so
  base→ours on core is empty and the three-way degenerates to a fast-forward.
- **extensions/** → never touched by the pull. Drain entries flagged
  `push_candidate: true` into the push-candidate ledger (spec §8.1).
- **overrides/** → the ONLY genuine three-way surface. For each override, its
  base is the core rule it shadows (`base_sha` in the entry). If theirs changed
  that core rule between `base_sha` and HEAD, surface the override for operator
  re-confirmation (override-drift, spec §10).

On a pre-Phase-2 (tangled) consumer like graph's first pull, none of the above
applies yet — run the full per-block classify. The Phase-2 untangle is what
moves a consumer from the full reconcile to this cheap one.

## Shared engine, thin orchestrator

The per-block classifier (`reconcile/classify-block.md`) is a SHARED engine
that serves four jobs (design §8): pull-reconcile (this skill), push-mine,
Phase-2 untangle, and N→1 fan-in dedupe. `ai-dlc-update` is only the **pull
entry point** that calls it — it does not own it. Keep the classifier prompt
free of pull-only assumptions so the other three jobs can reuse it.

## Not yet wired (design §6.1 gaps — call out, don't silently skip)

- **Upstream URL not in the stamp.** Until `.ai-dlc-version` carries the
  distribution ref, the operator supplies the distribution checkout path.
- **Self-update** is handled in step 2 as its own autonomous branch→commit→push
  →PR→auto-merge cycle (the skill's files are overwrite-safe upstream tooling, no
  operator gate), separate from the operator-gated rulebook reconcile (step 8).
  The operator is informed after and may re-invoke to run the current reconcile
  on the new logic.
