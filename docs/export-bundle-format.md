# AI/DLC Export Bundle Format

**Status:** design spec. Not yet implemented.

Specification for the export bundles produced by the `/ai-dlc-export`
skill (TBD). Bundles are the data exchange format between a consumer
project's accumulated lessons and the ai-dlc repo's intake/triage process.

## Purpose

A bundle is a structured set of candidate rule changes extracted from a
consumer project's divergence from installed upstream ai-dlc. Each bundle:

- Is produced by the `/ai-dlc-export` skill running against a consumer
  project, after an `install.sh` resync that captures divergent files into
  `docs/pre-ai-dlc/<timestamp>/` (flat + `_divergence/` layouts).
- Contains one candidate per divergent hunk, with enough context for the
  intake reviewer to weigh merge worthiness, resolve conflicts, guard
  against ruleset bloat, and detect hidden memory dependencies.
- Lives in the ai-dlc repo under `contributions/<bundle-id>/`, committed
  on a per-bundle branch.
- Gets triaged by the `/ai-dlc-intake` skill (or a structured prompt),
  with decisions recorded in-place.

## Directory layout

```
ai-dlc/
└── contributions/
    └── <bundle-id>/
        ├── MANIFEST.md              # index + status/verdict rollups
        ├── 001-<slug>.md            # one candidate per file
        ├── 002-<slug>.md
        └── ...
```

**Bundle ID:** `<YYYYMMDD>-<source-project-slug>` — e.g., `20260414-graph-pipeline`.
One directory per export run.

**Candidate filename:** `<3-digit-id>-<kebab-slug>.md` — e.g.,
`001-hard-rule-5-layer-enforcement.md`. Slug is derived from the
candidate title, truncated to ~40 characters.

**Branch:** each bundle gets its own branch `contributions/<bundle-id>`,
merged to main only when all candidates have reached terminal status.

## Candidate file format

Markdown with YAML frontmatter.

### Frontmatter schema

```yaml
---
id: 001                               # 3-digit zero-padded, sequence within bundle
status: draft                         # draft | reviewed | ready | accepted | rejected | deferred
target_file: .claude/skills/ai-dlc/steps/retro.md    # consumer-relative
target_lines: 47-65                   # line range in target_file
change_type: modification             # addition | modification | removal | softening
suggested_target:
  type: step_edit                     # core_rule | pattern | step_edit | team_role_edit | meta_rule
  path: core/skills/ai-dlc/steps/retro.md    # ai-dlc-repo-relative
scope: all                            # all | conditional
scope_condition:                      # free text if scope=conditional
bloat_verdict: clean-add              # clean-add | modify-existing | consolidate-multiple | reject-redundant
portability_verdict: standalone       # standalone | absorbable | parameterizable | blocks_upstream
---
```

| Field | Required | Set by | Notes |
|---|---|---|---|
| `id` | yes | export (auto) | Sequence within bundle, not global |
| `status` | yes | export (`draft`), intake updates | See state machine |
| `target_file` | yes | export (auto) | Path in consumer project |
| `target_lines` | yes | export (auto) | From hunk range |
| `change_type` | yes | export (auto) | From conflict detection |
| `suggested_target.type` | yes | export (auto), interview override | Abstraction level |
| `suggested_target.path` | yes | export (auto), interview override | Proposed upstream path |
| `scope` | yes | interview | Portability breadth |
| `scope_condition` | if scope=conditional | interview | Predicate text |
| `bloat_verdict` | yes | interview | See Bloat audit section |
| `portability_verdict` | yes | interview | See Memory dependency section |

### Body sections (in order)

1. **Title** — `# <id>: <short title>`
2. **Proposed change** — unified diff, `-U 10` context
3. **Origin** — sprint, triggering incident, retro reference
4. **Evidence** — fire count, sprints active, overrides, references
5. **Cross-layer wiring in consumer** — checkbox list of the 5 enforcement layers
6. **Generalizability assessment** — project-specific hooks, suggested abstraction, template vars
7. **Conflict map** — upstream overlap, inlined upstream text, reason for divergence, coverage diff
8. **Bloat audit** — existing overlapping rules, consolidation opportunity, cost/benefit, verdict
9. **Memory dependencies** — scanned locations, references found, portability verdict
10. **Reviewer decision** — filled during intake (empty during draft)

See [example candidate](#example-candidate-file) below for the body structure.

## Manifest format

```yaml
---
bundle_id: 20260414-graph-pipeline
source_project: graph-data-pipeline
source_project_commit: abc123
upstream_baseline_commit: def456      # ai-dlc sha at last install/resync
upstream_current_commit: xyz789       # ai-dlc sha at export time
exported_at: 2026-04-14T15:30:00Z
maintainer: n8
candidate_count: 14
status_counts:
  draft: 0
  reviewed: 8
  ready: 3
  accepted: 2
  rejected: 1
  deferred: 0
bloat_verdict_counts:
  clean-add: 8
  modify-existing: 4
  consolidate-multiple: 1
  reject-redundant: 1
portability_verdict_counts:
  standalone: 10
  absorbable: 2
  parameterizable: 1
  blocks_upstream: 1
---

# Export Bundle: <source-project>, <date>

<N> candidates from sprints <X>–<Y>. Resynced at upstream `<commit>`.

## Candidates by suggested target

### Step edits (N)
- [001](001-slug.md) — title [status]

### New patterns (N)
...

### Core rule edits (N)
...

### Team role edits (N)
...

### Meta rules (N)
...

## Bloat concerns

Generated by the export tool from candidate co-occurrence analysis.

- **Candidate clusters targeting same failure mode:** (by keyword overlap)
  - [003, 007, 012] — all target "requirement drift during implementation"
  - Recommendation: consolidate into one rule
- **Addition-to-modification ratio:** 9 adds / 2 modifies / 3 removals
  - High pure-add ratios signal accumulating bloat

## Portability concerns

- **Candidates blocked at export:** 1 — see [014](014-slug.md)
- **Candidates requiring parameterization:** 1 — see [009](009-slug.md)
```

The manifest's `*_counts` rollups are **derived** — the candidate files are
the source of truth. Export and intake skills regenerate rollups whenever
they touch a candidate.

## State machine

```
         [export]                    [intake]
candidate ──────> draft ──> reviewed ──> ready ──┬──> accepted
                                                 ├──> rejected
                                                 └──> deferred

         [export short-circuit]
candidate ──────> rejected    (when portability_verdict = blocks_upstream)
```

- **draft** — initial. Mechanical fields filled, interview empty.
- **reviewed** — maintainer has filled interview fields.
- **ready** — maintainer signoff; candidate is ready for intake.
- **accepted** — intake merged the change to upstream.
- **rejected** — intake declined. Bundle retained for negative-space history.
- **deferred** — intake postponed (e.g., requires parameterization work first).

**Export short-circuit:** if the interview determines `portability_verdict: blocks_upstream`,
the candidate moves directly to `rejected` without entering the intake queue.
Rationale: the candidate will never pass intake, so queuing it wastes reviewer
time. The maintainer logs the lesson to the consumer's `docs/ai-dlc-feedback.md`
as project-specific — keeping the record where it matters rather than polluting
upstream with a rejected history entry.

## Auto-populated vs. interview fields

The export skill runs per candidate and splits work between mechanical
capture and maintainer interview.

### Auto (from archive + git + grep)

- All frontmatter except `status`, `scope`, `scope_condition`, `bloat_verdict`,
  `portability_verdict`, and interview-driven overrides to `suggested_target`.
- Proposed change (unified diff from `docs/pre-ai-dlc/LATEST/_divergence/`
  vs. installed upstream mirror).
- Evidence:
  - **Fire count** — grep `_bmad-output/implementation-artifacts/gate-log.md`
    for references to the rule's keywords.
  - **Sprints active** — git log of `target_file` limited to commits that
    touched the rule's line range.
  - **Overrides/reverts** — grep `docs/escalations/pending.md` and git log
    for revert commits.
  - **Referenced in** — grep `docs/retro/`, `docs/escalations/`,
    `docs/ai-dlc-feedback.md`.
- Cross-layer wiring — grep each of the 5 enforcement-layer files for the
  rule's signature keywords.
- Conflict map — upstream path + inlined upstream text via `diff -U 10`
  against the mirror file in `core/` or `patterns/` of the ai-dlc repo.
- Bloat audit (auto portion) — keyword grep of rule signature against
  `core/` and `patterns/` to surface existing overlapping rules.
- Memory dependency scan (auto portion) — keyword grep against the four
  scanned locations (see Memory dependency check below).

### Interview (export skill prompts, one candidate at a time)

- **Origin:** sprint number, triggering incident one-liner, retro reference
- **Generalizability:** project-specific hooks, suggested abstraction, template vars
- **Conflict map:** reason for divergence, coverage diff (for modifications)
- **Bloat audit:** consolidation opportunity, marginal cost, benefit vs. cost, verdict
- **Memory dependencies:** per-reference dependency assessment, portability verdict
- **Scope:** `scope`, `scope_condition`
- **Suggested target overrides** if auto-detection picked wrong

## Conflict detection algorithm

For each file in `docs/pre-ai-dlc/LATEST/_divergence/`:

1. **Derive the mirror upstream path.**
   - `_divergence/.claude/skills/ai-dlc/*` → `core/skills/ai-dlc/*` in ai-dlc repo
   - `_divergence/.claude/skills/ai-dlc-setup/*` → `core/skills/ai-dlc-setup/*`
   - `_divergence/docs/ai-dlc-patterns/*` → `patterns/*`
   - Files with no mirror = consumer added new files; treat as pure additions.
2. **Run `diff -U 10`** between the archived consumer version and the mirror.
3. **Group adjacent hunks** within 5 lines of each other into one candidate.
   Non-adjacent hunks remain separate candidates.
4. **Classify each candidate's `change_type`:**
   - **addition** — hunk adds lines with no removals
   - **modification** — hunk has both additions and removals
   - **removal** — hunk removes lines with no additions
   - **softening** — subclass of modification where the consumer weakened
     an existing rule (e.g., `MUST` → `SHOULD`). Detected by weakening-keyword
     presence in removed text that's absent in added text.
5. **Populate the conflict map** — upstream path + line range, inline the
   upstream text block for in-bundle comparison during triage.

**Flat-archive files** (`CLAUDE.md`, `QUICKSTART.md`, `docs/coding-conventions.md`,
team role files) are also candidate sources, but are handled separately from
`_divergence/`:

- **Team role files** — diff against `core/team-roles/<role>.md`. Straightforward,
  no template noise.
- **`docs/coding-conventions.md`** — diff against `templates/coding-conventions.md.template`,
  filtering out template variable replacements with a regex exclusion
  (the wizard-replaced variables are expected divergence, not candidates).
- **`CLAUDE.md`, `QUICKSTART.md`** — heavily templated; too noisy for reliable
  automatic diffing. The export tool skips these in auto mode. The maintainer
  can manually flag candidates from these files during the interview phase.

## Bloat audit

Every candidate includes a bloat audit. Asks: does this candidate grow the
ruleset, and is that growth justified?

### Auto fields

**Existing upstream rules in the same failure-mode space** — keyword grep
against `core/` and `patterns/` using signature keywords extracted from
the diff's added lines. Reports matches as `file:line` with one-line excerpts.

### Interview fields

- **Consolidation opportunity** — `modify-existing` / `none` / `replace-existing`
- **Marginal cost:**
  - Read frequency: every retro / every deploy / every sprint
  - Token budget impact: negligible / moderate / significant
- **Benefit vs. cost** — fire count × severity from Evidence → maintainer assessment
- **Bloat verdict** (promoted to frontmatter):
  - `clean-add` — new failure mode, no overlap, justified
  - `modify-existing` — edit an existing rule instead of adding
  - `consolidate-multiple` — merge with other candidates in the bundle
  - `reject-redundant` — existing rule already covers this

### Manifest-level rollup

The MANIFEST's "Bloat concerns" section detects and reports:

- **Clusters of candidates** by keyword co-occurrence — candidates targeting
  the same failure mode should probably consolidate.
- **Addition-to-modification ratio** across the bundle — high pure-add
  ratios signal accumulating bloat.

## Memory dependency check

Every candidate includes a memory dependency scan. Asks: does this rule's
effectiveness depend on project-specific context that can't be captured in
the rule text?

### Scanned locations (auto)

1. **Claude Code cross-conversation memory** for the consumer project.
   Derive the memory path from the consumer project path:
   `/path/to/project` → `~/.claude/projects/<encoded-path>/memory/*.md`
   where `<encoded-path>` replaces `/` with `-` and prepends `-`.
2. **ai-dlc feedback log** — `docs/ai-dlc-feedback.md` in the consumer project.
3. **Retro history** — `docs/retro/*.md` in the consumer project.
4. **`CLAUDE.md` project-specific sections** — in the consumer project.

### Auto fields

**References found** — keyword grep against the rule signature across the
four scanned locations. Reports each match as `file:line` with a short excerpt.

### Interview fields

- **Dependency assessment** (per reference or overall):
  - Does the rule require this context to be interpreted correctly? yes/no
  - If yes, can the context be absorbed into the rule text? yes/no/partial
  - If partial, can it become a template variable with a default? yes/no
- **Portability verdict** (promoted to frontmatter):
  - `standalone` — rule works without the memory
  - `absorbable` — memory content merges into rule text (candidate's
    proposed change is updated to include the absorbed content)
  - `parameterizable` — memory becomes a template variable; candidate
    lists the new variables and their default values
  - `blocks_upstream` — rule is fundamentally project-specific, cannot generalize

A `blocks_upstream` verdict short-circuits the state machine (see above).

## Example candidate file

```markdown
---
id: 001
status: draft
target_file: .claude/skills/ai-dlc/steps/retro.md
target_lines: 47-65
change_type: modification
suggested_target:
  type: step_edit
  path: core/skills/ai-dlc/steps/retro.md
scope: all
bloat_verdict: modify-existing
portability_verdict: standalone
---

# 001: Enforce hard rules at all 5 enforcement layers

## Proposed change
​```diff
@@ -47,3 +47,18 @@
 ... unified diff with -U 10 context ...
​```

## Origin
- **Sprint:** 12
- **Triggering incident:** Advisory rule added in sprint 12 was ignored in 13–15
  until upgraded to hard gate at all 5 layers.
- **Retro reference:** `docs/retro/sprint-12.md:34`

## Evidence
- **Fired (caught a problem):** 7 times
- **Sprints active:** 19
- **Overrides / reverts:** 0
- **Referenced in:**
  - `docs/retro/sprint-14.md:17`
  - `_bmad-output/implementation-artifacts/gate-log.md:122`

## Cross-layer wiring in consumer
- [x] rule definition — `docs/coding-conventions.md:89`
- [x] gate validation — `.claude/skills/ai-dlc/steps/gate-validation.md:145`
- [x] dev checklist — `.claude/team-roles/dev.md:67`
- [x] code reviewer — `.claude/team-roles/code-reviewer.md:23`
- [x] QA validation — `.claude/team-roles/qa.md:34`

## Generalizability assessment
- **Project-specific hooks:** none
- **Suggested abstraction:** direct edit to `core/skills/ai-dlc/steps/retro.md`
- **Template variables needed:** none

## Conflict map
- **Overlaps upstream rule at:** `core/skills/ai-dlc/steps/retro.md:48-65`
- **Upstream text (inlined for comparison):**
  > ... upstream lines pasted inline ...
- **Reason for divergence:** Upstream text is advisory; consumer made it
  prescriptive after sprint 12 incident showed advisory wasn't enough.
- **Coverage diff:**
  - Consumer catches: hard-rule drift in rushed retros
  - Upstream catches: same, if retro is thorough
  - Net: consumer is stricter, no regression

## Bloat audit
- **Existing upstream rules in same failure-mode space:**
  - `core/skills/ai-dlc/steps/retro.md:48-65` (the text being modified)
- **Consolidation opportunity:** modify-existing
- **Marginal cost:** read every retro, negligible token impact
- **Benefit vs. cost:** 7 fires × critical severity → worth it
- **Bloat verdict:** modify-existing

## Memory dependencies
- **References found:** none across all four scanned locations
- **Dependency assessment:** rule is self-contained
- **Portability verdict:** standalone

## Reviewer decision
<empty during draft; intake fills during triage>
```

## Open design items

Tracked separately from this spec:

- `/ai-dlc-export` skill design — how the export tool is invoked, how it
  prompts the maintainer through the interview phase, how it writes the
  bundle.
- `/ai-dlc-intake` skill design — how bundles are triaged, how decisions
  are recorded, how accepted candidates are applied to upstream files.
- Contribution rubric (`docs/contribution-rubric.md`) — the merge criteria
  the intake skill evaluates candidates against.
