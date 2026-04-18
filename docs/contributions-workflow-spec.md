# Contributions Workflow: Build Spec

**Status:** design spec. Three pieces to build on this branch
(`contributions-workflow`). Foundation already on `main`.

## Goal

Enable a maintainer of the ai-dlc skillset to extract accumulated
lessons from a consumer project (30+ sprints of divergent rules) and
systematically merge the worthy ones back into the ai-dlc upstream
repo.

The workflow has two sides:

- **Producer (consumer project side):** the maintainer runs a resync
  to pick up latest upstream — `scripts/install.sh` captures divergent
  files to `docs/pre-ai-dlc/<timestamp>/` (flat for Step 0 absorption
  targets, `_divergence/` for skill/step/pattern files the export tool
  reads). Then the maintainer runs `/ai-dlc-export` to walk the
  archive, interview the maintainer per candidate, and write a
  structured bundle.
- **Consumer (ai-dlc repo side):** the maintainer runs `/ai-dlc-intake`
  on a bundle to triage each candidate against the contribution rubric
  and apply accepted changes to the upstream files.

Invocation is **maintainer-driven and ad hoc**, not auto-triggered by
retros. Audience is a handful of trusted users, not public.

## Foundation already on main

These commits are in place and must not be re-litigated:

- `3ac0b54` — Archive skill/step files and spec the export bundle format
- `03163b7` — Harden rule-writing requirements and add retro audit (Rule 11)
- `3039959` — Strip narrative and harden weak rules (Rule 11 audit)

This branch is based on `3039959`.

## Prior decisions to preserve

All of these were settled in the design conversation that produced
this spec. Do not re-open them unless genuinely blocked.

1. **Resync-then-export flow.** The maintainer runs `scripts/install.sh`
   against the consumer project on a feature branch. The installer
   archives divergent files to `docs/pre-ai-dlc/<timestamp>/`:
   - Flat (archive root): `CLAUDE.md`, `QUICKSTART.md`,
     `coding-conventions.md`, team role files — Step 0 absorption targets.
   - `_divergence/` (mirrors project-relative paths): skill files,
     step files, setup skill, pattern files — export-tool targets.
   See `scripts/install.sh` and `docs/export-bundle-format.md` for the
   exact layout.

2. **Bundle format is fully specified** in `docs/export-bundle-format.md`.
   Includes candidate frontmatter schema, body sections, manifest
   rollups, state machine, conflict detection algorithm, bloat audit,
   memory dependency check. The export skill MUST produce bundles
   matching this format. The intake skill MUST read and update them
   in place.

3. **Bundles live in the ai-dlc repo** under `contributions/<bundle-id>/`,
   one branch per bundle (`contributions/<bundle-id>`). Committed for
   durable history including rejected candidates (negative-space info).

4. **Bloat and memory verdicts are promoted to frontmatter.**
   `bloat_verdict` and `portability_verdict` are first-class fields,
   not just body sections. Short-circuit: a `portability_verdict` of
   `blocks_upstream` moves the candidate directly to `rejected` at
   export time, skipping intake entirely.

5. **Memory scan sources are fixed at four locations** (do not expand):
   - Claude Code cross-conversation memory for the consumer project
     (`~/.claude/projects/<encoded-path>/memory/*.md`)
   - `docs/ai-dlc-feedback.md` in the consumer project
   - `docs/retro/*.md` in the consumer project
   - CLAUDE.md project-specific sections in the consumer project

6. **Conflict detection via mirror path.** Consumer's
   `_divergence/.claude/skills/ai-dlc/steps/retro.md` mirrors to
   `core/skills/ai-dlc/steps/retro.md` in the ai-dlc repo. Run
   `diff -U 10` between them. Group hunks within 5 lines into one
   candidate. Pure additions, modifications, removals, and softenings
   are all first-class candidates.

7. **Rule 11 applies to every rule file the workflow touches.** Any
   rule text written by the export or intake skill (including candidate
   bodies that get applied to upstream files) MUST comply with Rule 11:
   imperative or MUST/MUST NOT/SHALL, no sprint references, no origin
   narrative, no "because" justification. The WHY lives in the commit
   message, not the rule text.

8. **Candidate bodies are themselves review artifacts** — they capture
   origin/WHY extensively for the intake reviewer. This is an explicit
   Rule 18 scope carveout (see SKILL.md Rule 18 Scope section). When
   intake accepts a candidate, the applied rule text is stripped of
   narrative before it lands in the upstream file; the WHY goes to
   the intake commit message.

9. **No auto-rejection from the rubric.** The rubric informs the
   maintainer's decision but doesn't auto-reject candidates. Every
   reject/accept/defer decision is maintainer-approved. The only
   auto-rejection is the `blocks_upstream` short-circuit at export
   time (item 4 above).

## Build order

### Step 1 — Contribution rubric (`docs/contribution-rubric.md`)

Shortest piece. Feeds the other two: export uses it to pre-fill hints
during the maintainer interview; intake reads it on every triage.

Content to cover:

- **Per-candidate merge criteria.** Checkbox or criteria list the
  intake reviewer walks through per candidate. Draws on bundle data:
  evidence (fire count, sprints active, overrides), generalizability
  (project-specific hooks, suggested abstraction), conflict map
  (reason for divergence, coverage diff), bloat audit (consolidation
  opportunity, marginal cost), memory dependency (portability verdict).
- **Verdict mapping.** What combinations of criteria lead to which
  decision (accept / reject / defer). Keep this prescriptive (per
  Rule 11) — no "in most cases" hedging.
- **Edge cases.** How to handle:
  - New patterns vs. core rule edits (different commit patterns)
  - `scope: conditional` candidates that need a predicate in the
    pattern's "When to use" section
  - Candidates that require new template variables
  - Candidates modifying an existing upstream rule vs. adding new
  - Candidates whose `change_type` is `removal` or `softening`
    (evidence that upstream should weaken/remove a rule)
- **Cross-bundle rules.** How to handle candidates that overlap other
  pending bundles. Lean: first-come ordering, later bundles rebase.

The rubric is Rule 11 compliant itself.

### Step 2 — `/ai-dlc-export` skill

Location: `core/skills/ai-dlc-export/SKILL.md` + supporting step files.

**Inputs:** consumer project path (argument or prompt).
**Outputs:** bundle directory in the ai-dlc repo under
`contributions/<bundle-id>/` on a new branch `contributions/<bundle-id>`.

**Execution sequence:**

1. **Prerequisites check.** Verify `docs/pre-ai-dlc/<latest>/_divergence/`
   exists in the consumer project. If not, tell the maintainer to run
   `scripts/install.sh` first and stop.

2. **Bundle initialization.** Compute bundle ID as
   `<YYYYMMDD>-<consumer-project-slug>`. Create branch in the ai-dlc
   repo: `contributions/<bundle-id>`. Create the bundle directory.
   Initialize `MANIFEST.md` with frontmatter (empty status counts).

3. **Candidate discovery.** For each file under the consumer's
   `_divergence/`:
   - Find the mirror upstream file in the ai-dlc repo by path rule
     (`.claude/skills/ai-dlc/*` ↔ `core/skills/ai-dlc/*`,
     `.claude/skills/ai-dlc-setup/*` ↔ `core/skills/ai-dlc-setup/*`,
     `docs/ai-dlc-patterns/*` ↔ `patterns/*`).
   - If no mirror exists, treat as a new file added by the consumer
     (pure addition, `suggested_target.path` proposed from the
     file's position).
   - Run `diff -U 10`. Group adjacent hunks within 5 lines. Each
     group becomes a candidate.
   - Classify `change_type`: addition, modification, removal, softening.

4. **Mechanical capture per candidate.** Populate auto fields:
   - Frontmatter (except `status`, interview fields)
   - Proposed change (diff)
   - Evidence section (fire count, sprints active, references —
     from grep of consumer's gate-log, retros, escalations, feedback log)
   - Cross-layer wiring (grep the consumer's 5 enforcement-layer files)
   - Conflict map (upstream path, inlined upstream text)
   - Bloat audit — upstream grep for similar rules
   - Memory dependency scan — grep the 4 fixed sources

   See `docs/export-bundle-format.md` for the exact field split.

5. **Maintainer interview per candidate.** Sequential, one at a time.
   Prompt for:
   - Origin (sprint, triggering incident, retro reference)
   - Generalizability assessment (project-specific hooks, suggested
     abstraction, template variables)
   - Reason for divergence (if modification) + coverage diff
   - Bloat verdict (consult auto-populated overlaps)
   - Portability verdict (consult auto-populated memory references)
   - Scope and scope_condition
   - Any override to `suggested_target` if auto-detection picked wrong

   **Short-circuit:** if the maintainer chooses
   `portability_verdict: blocks_upstream`, mark the candidate
   `rejected`, prompt the maintainer to log the lesson to the
   consumer's `docs/ai-dlc-feedback.md` as project-specific, and move
   on to the next candidate.

6. **Write candidate file.** Render to
   `contributions/<bundle-id>/<3-digit-id>-<kebab-slug>.md` with all
   fields filled in per the bundle format spec.

7. **Update MANIFEST.md.** Recompute `status_counts`,
   `bloat_verdict_counts`, `portability_verdict_counts`. Update the
   "Candidates by suggested target" section and bloat/portability
   concern sections.

8. **Commit and push.** Stage the bundle directory. Commit with a
   message referencing bundle ID and candidate count. Push the branch.
   Report: branch name, candidate count, blocks_upstream count,
   status breakdown, next step for the maintainer (switch to the
   branch in the ai-dlc repo and run `/ai-dlc-intake`).

**Open design questions** (to resolve during build — not blockers):

- **Pause/resume.** If the maintainer stops mid-interview, how is state
  preserved? Lean: write each candidate file as it's completed;
  MANIFEST.md tracks progress. On resume, skip candidates that already
  exist in the bundle directory.
- **Where the skill runs.** The skill lives in the ai-dlc repo
  (`core/skills/ai-dlc-export/`). It takes the consumer project path
  as input. The maintainer runs it from the ai-dlc repo, not the
  consumer project. This keeps the consumer install surface small.
- **Whether export skills are installed into consumer projects.** Lean:
  no. Export/intake are ai-dlc-repo-only tools for maintainers. Do not
  extend `scripts/install.sh` to copy them into consumer projects.

### Step 3 — `/ai-dlc-intake` skill

Location: `core/skills/ai-dlc-intake/SKILL.md` + supporting step files.

**Inputs:** a bundle directory on the current branch.
**Outputs:** applied upstream changes, updated candidate statuses,
commits on the bundle branch.

**Execution sequence:**

1. **Prerequisites check.** Verify the current branch matches
   `contributions/<bundle-id>` and the bundle directory exists. If
   not, tell the maintainer to check out the bundle branch and stop.

2. **Load the bundle.** Read `MANIFEST.md`. Read each candidate file.
   Collect candidates whose `status` is `ready` (skip `draft`,
   `reviewed`, `accepted`, `rejected`, `deferred`).

3. **Per-candidate triage.** For each ready candidate:
   - Read the candidate against `docs/contribution-rubric.md`
   - Present the candidate + rubric checks to the maintainer
   - Prompt: accept / reject / defer
   - If accept: prompt for any final wording adjustments before
     applying
   - Update the candidate's `status` field to the chosen value
   - Fill in the "Reviewer decision" section

4. **Apply accepted candidates.** For each `accepted` candidate:
   - Resolve `suggested_target.type` and `.path`:
     - `pattern`: create a new file under `patterns/<slug>.md`
     - `core_rule`, `step_edit`, `team_role_edit`, `meta_rule`:
       apply the change in place to the target file
   - **Strip narrative before applying.** The candidate body carries
     origin/WHY for the reviewer; the applied rule text MUST be
     Rule 11 compliant. Move the WHY to the commit message.
   - Commit the applied change with a message referencing the
     candidate ID and the target file.

5. **Update MANIFEST.** Recompute status and verdict counts. Commit
   manifest updates separately from the applied-change commits so
   code changes stay bisectable.

6. **Per-bundle rule file audit.** After all candidates are triaged,
   run a Rule 11 audit over the files intake touched (mirror the
   pattern from `retro.md` Step 4 rule file audit). Commit any sweep
   findings.

7. **Report.** Summary: X accepted, Y rejected, Z deferred, W files
   modified. The maintainer reviews the branch and opens a PR to
   main (or merges directly, depending on process).

**Open design questions:**

- **Cross-bundle conflicts.** If bundles A and B both propose edits to
  the same rule and A lands first, B has to rebase. Lean: simple
  first-come order; flag the conflict during intake and stop for
  maintainer resolution.
- **Partial acceptance.** Can a maintainer accept part of a candidate
  hunk and reject the rest? Lean: no — atomic per candidate. If the
  maintainer wants to split, they edit the candidate file first to
  split it into two, then re-triage.

## Integration points

- **`scripts/install.sh` archive format** — export reads
  `docs/pre-ai-dlc/<latest>/_divergence/`. Already in place.
- **Bundle format spec** — `docs/export-bundle-format.md`. Both skills
  must round-trip it.
- **Rule 11** — `templates/CLAUDE.md.template` Rule 11. All written
  rule text (not candidate bodies) must comply.
- **Retro audit** — `core/skills/ai-dlc/steps/retro.md` Step 4 rule
  file audit. If intake writes non-compliant text, the next retro
  audit in a consumer project WILL flag it, so the intake skill's
  own pre-commit Rule 11 check is insurance.
- **Contribution rubric** — `docs/contribution-rubric.md` (built in
  Step 1 above). Intake reads on every triage.

## Success criteria

The workflow is done when:

1. `docs/contribution-rubric.md` committed, Rule 11 compliant.
2. `core/skills/ai-dlc-export/` committed with `SKILL.md` and any
   supporting step files.
3. `core/skills/ai-dlc-intake/` committed with `SKILL.md` and any
   supporting step files.
4. One full end-to-end pass has been exercised against a real
   consumer project (or a realistic mock), producing a valid bundle
   that intake can process.
5. All commits on this branch are Rule 11 compliant.
6. The branch is ready to merge to `main` as one cohesive change.

## What to read before starting

In order:

1. **This spec.**
2. `docs/export-bundle-format.md` — the bundle format spec. The
   export skill produces this; the intake skill consumes it.
3. `scripts/install.sh` — the archive layout the export skill reads.
4. `core/skills/ai-dlc/steps/retro.md` — the rule file audit pattern
   the intake skill mirrors.
5. `templates/CLAUDE.md.template` — Rule 11. All written rule text
   must comply.
6. `core/skills/ai-dlc/SKILL.md` — existing skill structure to match
   (frontmatter format, routing pattern, critical rules section).
7. `core/skills/ai-dlc-setup/SKILL.md` — another skill structure
   reference, specifically for interactive/wizard-style flow.
8. `patterns/*.md` — any pattern file, to see the target format for
   candidates whose `suggested_target.type` is `pattern`.
