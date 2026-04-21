---
name: ai-dlc-setup
description: "Guided configuration wizard for AI/DLC. Run bare for full setup, or with a section name to jump directly: /ai-dlc-setup [models|deploy|ownership|operations|launch|conventions|patterns|validate]"
effort: medium
---

# AI/DLC Setup Wizard

You are the AI/DLC configuration wizard. Your job is to guide the user
through configuring AI/DLC for their project — replacing all template
variables with project-specific values, selecting enforcement patterns,
and validating the result.

## CRITICAL RULES

1. **Ask, don't guess.** When you can auto-detect a value, present it
   for confirmation. When you cannot, ask the user directly.
2. **One section at a time.** When running a section, walk through it
   completely before moving to the next.
3. **Replace, don't append.** Template variables like `{deploy_command}`
   must be replaced with actual values. Do not leave any `{variable}`
   placeholders in the final files (except `{project-root}`, which is a
   Claude Code runtime variable).
4. **Preserve HTML comments.** The `<!-- ... -->` comments are inline
   documentation. Leave them in place after replacing the bare variable.
5. **Idempotent.** If a variable is already replaced (the literal
   `{variable_name}` string is not present in the file), skip it and
   note that it was already configured.

## ROUTING

Parse the user's invocation to determine the entry point.

**Argument mapping** — if the user provided an argument after
`/ai-dlc-setup`, map it to a step:

| Argument | Jump to |
|----------|---------|
| `models` | Step 2 (API Tier and Model Strings) |
| `deploy` | Step 3 (Deployment Configuration) |
| `ownership` | Step 4 (Ownership Paths) |
| `operations` | Step 5 (Operations Protocol) |
| `launch` | Step 6 (Launch Configuration) |
| `conventions` | Step 7 (Coding Conventions) |
| `patterns` | Step 8 (Pattern Selection) |
| `validate` | Step 9 (Validation Sweep) |
| `uninstall` | Uninstall (see below) |

If the argument is `uninstall`, skip all other steps. Tell the user:

> To remove AI/DLC from this project, run from the ai-dlc repo:
> ```
> ./scripts/uninstall.sh /path/to/this-project
> ```
> This removes all AI/DLC skills, team roles, templates, and pattern
> references. It preserves your planning artifacts (`_bmad-output/`),
> code reviews (`docs/reviews/`), and retrospectives (`docs/retro/`).
>
> Add `--force` to skip the confirmation prompt.

Then stop. Do not proceed to any other step.

If an argument matches, run the project scan (Step 1) silently — do NOT
present the scan summary or ask for confirmation. Use the scan results
as context, then jump directly to the matched step. After completing
that step, run the validation sweep (Step 9) and the summary (Step 10),
scoped to what was just changed.

**No argument — fresh install detection:**

If no argument was provided, run the project scan (Step 1) and check
for remaining template variables:

```bash
grep -rn '{[a-z_]*}' .claude/skills/ai-dlc/ .claude/team-roles/ CLAUDE.md QUICKSTART.md docs/coding-conventions.md 2>/dev/null | grep -v '{project-root}' | grep -v '<!--'
```

- **If template variables remain:** This is a fresh or partial install.
  Present the scan summary (Step 1) and then walk through steps 2-10
  sequentially, skipping any step whose variables are already configured.

- **If NO template variables remain:** This is a returning user.
  Present a section menu:

  ```
  AI/DLC is already configured. What would you like to update?

  1. Models         — API tier and model strings
  2. Deploy         — Deploy and smoke test commands
  3. Ownership      — Dev and QA directory ownership
  4. Operations     — Deployment infrastructure rules
  5. Launch         — Shell launch function
  6. Conventions    — Coding conventions sections
  7. Patterns       — Add or reconfigure enforcement patterns
  8. Validate       — Check for remaining template variables
  9. Full setup     — Re-run the entire wizard from the beginning
  10. Uninstall     — Remove AI/DLC from this project

  Enter a number or name (e.g., "7" or "patterns"):
  ```

  Wait for the user's selection, then jump to that step. After
  completing it, run validation (Step 9) and a scoped summary (Step 10).

  If the user selects "9" or "full setup", run the entire wizard from
  Step 1 as if it were a fresh install (present scan, walk all steps).

## PREREQUISITES CHECK

Before starting (regardless of entry point), verify the AI/DLC
installation exists:

```
Check for these files:
- .claude/skills/ai-dlc/SKILL.md
- .claude/team-roles/dev.md
- CLAUDE.md
```

If any are missing, tell the user:
> AI/DLC files not found. Run the installer first:
> `./path/to/ai-dlc/scripts/install.sh /path/to/this-project`

If all exist, proceed to routing.

---

## STEP 0: Absorb Existing Configuration

**This step runs automatically before Step 1 if archived files exist.**

Check if `docs/pre-ai-dlc/` exists. This directory is created by
`install.sh` when the project had existing files (CLAUDE.md, team roles,
coding-conventions.md) before AI/DLC was installed. The originals were
archived there in timestamped subdirectories (e.g.,
`docs/pre-ai-dlc/20260322-143012/`).

If `docs/pre-ai-dlc/` does NOT exist, skip to Step 1.

If it exists, find the **most recent** timestamped subdirectory (sort
alphabetically, take the last one — the timestamp format ensures
chronological ordering). Read archived files from that directory.

If it exists, read each archived file and extract project-specific
content that should be preserved. Do this silently — collect the
information now and apply it during the relevant configuration steps.

### 0a: Absorb CLAUDE.md

Read `CLAUDE.md` from the most recent archive (if it exists) and extract:

- **Project-specific rules or conventions** — anything that governs
  how agents should behave in this specific project (deployment targets,
  environment constraints, domain-specific rules)
- **File paths and references** — project-specific paths, key files,
  documentation pointers
- **Tool or service configuration** — API endpoints, service names,
  infrastructure details
- **Coding standards** — if coding conventions were inline in CLAUDE.md
  rather than in a separate file

Do NOT absorb:
- Generic agent behavior rules that conflict with AI/DLC's autonomy
  model (e.g., "always ask before proceeding" — AI/DLC has its own
  gate protocol)
- Validation or review processes — AI/DLC replaces these with its
  own three-gate model
- Team role definitions — AI/DLC provides its own

**When `prior_ai_dlc_install == true`, also DO NOT absorb any of the
following sections from the archived CLAUDE.md. These sections were
owned by AI/DLC in pre-R22 installs and have moved to new
authoritative locations in R22. The new locations are already
installed by `install.sh`; re-injecting the archived prose into the
new thin CLAUDE.md or the new coding-conventions.md would duplicate
content and create drift.**

Detect these sections by matching header text (case-insensitive,
match either `## Header` or `### Header` level). Skip the entire
section body up to the next same-or-higher-level header:

| Pre-R22 section header | Moved to |
|---|---|
| Autonomy Rules | SKILL.md Rules 1 through 20 |
| Autonomy Rule (any individual rule) | SKILL.md Rules 1 through 20 |
| Autonomous Gate Protocol | gate-validation.md |
| Phase Reference / Phase Table | route.md Step 6 |
| Session Model | SKILL.md Handoff Protocol |
| Post-Gate Deployment | deploy-validate.md |
| Post-Compact Recovery Protocol | SKILL.md |
| Story Validation Origin Check | gate-validation.md Check 3a |
| Pre-Deploy Schema/API Field Check | docs/coding-conventions.md |

Record the list of detected-and-excluded sections as
`r22_excluded_sections` for use in the Step 0e absorption summary.

When `prior_ai_dlc_install == false`, ignore this rule. The archived
CLAUDE.md is a project file unrelated to AI/DLC; section headers
that happen to match the table above are the user's own content and
should be evaluated against the general absorption criteria above.

Store the extracted content. You will use it in:
- Step 5 (Operations Protocol) — infrastructure rules
- Step 7 (Coding Conventions) — project-specific conventions
- Any relevant template variable replacement where the archived
  content provides the answer

**Also detect prior-install markers and prior `auto_handoff_mode`:**

- **Prior AI/DLC install marker.** Check whether
  `docs/pre-ai-dlc/<latest>/_divergence/.claude/skills/ai-dlc/SKILL.md`
  exists in the latest archive. If present, the archive is from a
  prior AI/DLC install. Record `prior_ai_dlc_install = true`. If
  absent (or the `_divergence/` tree is missing), record
  `prior_ai_dlc_install = false` — the archived CLAUDE.md, if any,
  is a project file unrelated to AI/DLC.

- **Archived `auto_handoff_mode` value.** Grep the archived
  `CLAUDE.md` for a line matching `^auto_handoff_mode:\s*(\w+)$` (in
  or near the Session Model block). If found, record the captured
  value as `archived_auto_handoff_mode`. If not found, record
  `archived_auto_handoff_mode = none`.

Store both values. Auto-handoff configuration now lives in SKILL.md
Handoff Protocol "Auto-handoff" section, not in CLAUDE.md, so the
archived value is recorded for reference only and is NOT written
back to the new CLAUDE.md. Surface the detected value in the
absorption summary so the user knows whether to edit SKILL.md to
preserve a non-default mode.

### 0b: Absorb Team Roles

For each archived role file in the most recent archive (architect.md,
code-reviewer.md, dev.md, pm.md, qa.md), read and extract:

- **Ownership paths** — which directories/files the role owned
- **Model preferences** — any model strings already configured
- **Project-specific responsibilities** — domain-specific duties
  beyond AI/DLC's defaults
- **Custom constraints** — project-specific rules for the role

Store the extracted content. You will use it in:
- Step 2 (Models) — if model strings were already configured
- Step 4 (Ownership) — if ownership paths were already defined

### 0c: Absorb Coding Conventions

Read `coding-conventions.md` from the most recent archive (if it exists) and extract:

- **Language/framework conventions** — linting, formatting, patterns
- **API conventions** — versioning, schema rules
- **Review standards** — project-specific review criteria
- **Impact classifications** — if defined
- **High-cost action gates** — if defined

Store the extracted content for Step 7 (Coding Conventions).

**Pre-Deploy Schema/API Field Check duplicate guard.** The new
`coding-conventions.md.template` (installed by `install.sh`) already
contains a Pre-Deploy Schema/API Field Check section. When absorbing
from the archived `coding-conventions.md`, detect whether a section
with this name or substantially similar content exists. If found:

- If `prior_ai_dlc_install == true`: DO NOT absorb the archived
  version. The section is already present in the new template.
  Record this as `r22_skipped_coding_conventions_pre_deploy = true`
  for the Step 0e summary.
- If `prior_ai_dlc_install == false`: the archived content is the
  user's own work. Present it to the user in Step 7 alongside the
  template version and ask which to keep.

This guard prevents the most common R22 upgrade duplication case
(pre-R22 projects with the check in CLAUDE.md, which `install.sh`
archives to both CLAUDE.md and coding-conventions.md).

### 0d: Conflict Detection

Compare the absorbed content against AI/DLC's operating model. Flag
any directives that contradict AI/DLC's core rules:

| AI/DLC Rule | Potential Conflict |
|---|---|
| Autonomous operation with single human checkpoint | "Always ask before proceeding" |
| Three-gate validation model | Custom review/approval workflows |
| Escalation tiers (HARD_BLOCK, DECIDED_AUTONOMOUSLY) | Different escalation models |
| Agent Teams with role ownership | Different team structures |
| BMAD Method for planning | Different planning frameworks |

For each conflict found, note it. You will present conflicts to the
user during the relevant configuration step and ask which takes
precedence. If the user picks their existing rule, add it as an
explicit override in the `CLAUDE.md` operations protocol or coding
conventions section with a comment explaining it overrides the AI/DLC
default.

### 0e: Absorption Summary

After reading all archived files, present a brief summary to the user:

```
## Existing Configuration Detected

Archived files found in docs/pre-ai-dlc/:
[list files found]

Prior AI/DLC install detected: [yes | no]

Absorbed content:
- [ownership paths / model strings / conventions / etc.]

Conflicts with AI/DLC defaults:
- [list conflicts, or "none detected"]

Prior auto-handoff mode (if detected): [value, or "none"]
  Auto-handoff configuration now lives in SKILL.md Handoff Protocol,
  not CLAUDE.md. If you ran a non-default mode previously, edit
  `.claude/skills/ai-dlc/SKILL.md` after setup to set it again.

Pre-R22 sections NOT absorbed (moved to new locations):
  [only shown when prior_ai_dlc_install == true AND at least one
   section in r22_excluded_sections was detected]
  - [section name] -> [new location]
  - ...
  These sections were owned by AI/DLC in your previous install and
  have moved. The new locations are already installed. Your archived
  copies remain in docs/pre-ai-dlc/<timestamp>/ for reference.

Duplicate guards applied:
  [only shown when prior_ai_dlc_install == true AND at least one
   guard fired]
  - Pre-Deploy Schema/API Field Check: skipped (already in the new
    coding-conventions.md template)

This content will be incorporated during setup. You'll have a chance
to review and confirm at each step.
```

Wait for acknowledgment, then proceed to Step 1.

---

## STEP 1: Project Scan

Scan the project to gather context. Check for the existence of each item
below and note what you find. Do NOT ask the user anything yet.

**Language and framework detection:**
- `package.json` (read: name, scripts, dependencies, devDependencies)
- `tsconfig.json` or `jsconfig.json`
- `go.mod`
- `Cargo.toml`
- `requirements.txt` or `pyproject.toml` or `setup.py`
- `Gemfile`
- `pom.xml` or `build.gradle`
- `mix.exs`

**Build and deploy detection:**
- `Makefile` (read target names, especially deploy/build/test targets)
- `docker-compose.yml` or `docker-compose.yaml` or `Dockerfile`
- `vercel.json`
- `netlify.toml`
- `fly.toml`
- `render.yaml`
- `Procfile`
- `scripts/deploy*` or `bin/deploy*`

**CI/CD detection:**
- `.github/workflows/*.yml`
- `.gitlab-ci.yml`
- `Jenkinsfile`
- `.circleci/config.yml`

**API layer detection:**
- `*.graphql` files or `schema.graphql` or `codegen.ts` or `codegen.yml`
- `openapi.yaml` or `openapi.json` or `swagger.json` or `swagger.yaml`
- `*.proto` files

**Directory structure:**
- Run `ls` at the project root
- Check for: `src/`, `app/`, `lib/`, `server/`, `client/`, `components/`,
  `pages/`, `routes/`, `api/`, `pkg/`, `internal/`, `cmd/`
- Check for test dirs: `tests/`, `test/`, `__tests__/`, `spec/`,
  `e2e/`, `cypress/`, `playwright/`, `tests/e2e/`, `tests/integration/`

**Existing configuration:**
- Check if `CLAUDE.md` still contains `{project_operations_protocol}`
  (literal string) — if not, it was already configured
- Check if `docs/coding-conventions.md` still contains
  `{project_general_conventions}` (literal string)

Present a summary to the user:

```
## Project Scan Results

**Language/Framework:** [detected]
**Build system:** [detected or "none detected"]
**Deploy target:** [detected or "none detected"]
**Test framework:** [detected or "none detected"]
**API layer:** [GraphQL / REST / gRPC / none detected]
**Directory structure:** [key directories found]
**CI/CD:** [detected or "none detected"]

Already configured: [list any sections where template variables are
already replaced, or "none — fresh install"]
```

Ask: "Does this look right? Anything to add or correct before we proceed?"

Wait for confirmation, then proceed to Step 1b.

---

## STEP 1b: Project Identity

CLAUDE.md opens with a one-paragraph description of this project so
that any engineer (AI/DLC pipeline or not) reading the file knows
what they are looking at. Resolve the `{project_identity}`
placeholder.

Detect a candidate description from the project scan: the
`description` field in `package.json` / `pyproject.toml` /
`Cargo.toml`, the first paragraph of `README.md`, or the first
descriptive line of an existing `CLAUDE.md` archive (Step 0).

Prompt the user:

> **Project identity.** CLAUDE.md opens with a one-paragraph
> description of this project. What is this project, who uses it,
> what does the codebase contain? A few sentences is plenty.
>
> Detected: [insert candidate description, or "nothing detected"]

Accept free-text input. Replace `{project_identity}` in `CLAUDE.md`
with the confirmed text. If the user enters nothing or skips, leave
the surrounding HTML comment in place and remove the
`{project_identity}` placeholder so the file validates cleanly in
Step 9.

**Files to replace in for `{project_identity}`:**

**`CLAUDE.md`:**
- `{project_identity}` (top of file, immediately after the
  Project Intelligence header) → confirmed description text

After confirmation, proceed to Step 2.

---

## STEP 2: API Tier and Model Strings

Ask the user:

> **Which API provider are you using?**
> 1. **Personal** — Direct Anthropic API (default)
> 2. **AWS Bedrock**
> 3. **Both** — Configure both, switch per session

**If the user selects Bedrock (option 2 or 3), ask a follow-up:**

> **Which models do you have access to on Bedrock?**
> 1. **Opus and Sonnet** — Full model strategy (opus for planning, sonnet for implementation)
> 2. **Sonnet only** — All roles use Sonnet (effort levels compensate for planning depth)

This determines the **model strategy mode**:
- **Full** (Personal, or Bedrock with Opus+Sonnet): Planning roles use
  opus, implementation roles use sonnet.
- **Sonnet-only** (Bedrock with Sonnet only): ALL roles use sonnet.
  Effort levels (`high` for planning roles) compensate partially for
  the less capable model. The pipeline still works but planning phases
  may be less thorough.

If Step 0 absorbed model strings from archived team role files, present
them as the detected defaults instead of the standard defaults below.

Based on the answer, determine the model strings. Use these defaults
unless the user specifies different models or Step 0 absorbed existing
model strings:

**Full model strategy (default):**

| Role           | Personal                    | Bedrock                                  | Effort |
|----------------|-----------------------------|------------------------------------------|--------|
| Lead           | claude-opus-4-6[1m]         | global.anthropic.claude-opus-4-6-v1      | high   |
| PM             | claude-opus-4-6[1m]         | global.anthropic.claude-opus-4-6-v1      | high   |
| Architect      | claude-opus-4-6[1m]         | global.anthropic.claude-opus-4-6-v1      | high   |
| Code Reviewer  | claude-opus-4-6[1m]         | global.anthropic.claude-opus-4-6-v1      | high   |
| Dev            | claude-sonnet-4-6           | global.anthropic.claude-sonnet-4-6       | medium |
| QA             | claude-sonnet-4-6           | global.anthropic.claude-sonnet-4-6       | medium |

**Sonnet-only model strategy:**

| Role           | Bedrock                                  | Effort |
|----------------|------------------------------------------|--------|
| Lead           | global.anthropic.claude-sonnet-4-6       | high   |
| PM             | global.anthropic.claude-sonnet-4-6       | high   |
| Architect      | global.anthropic.claude-sonnet-4-6       | high   |
| Code Reviewer  | global.anthropic.claude-sonnet-4-6       | high   |
| Dev            | global.anthropic.claude-sonnet-4-6       | medium |
| QA             | global.anthropic.claude-sonnet-4-6       | medium |

Ask: "Do you want to use a local model (e.g., Ollama) for dev teammates
on well-scoped stories? If yes, what model string?" (Default: skip)

Present the applicable model assignment table and ask for confirmation.

After confirmation, replace in these files. For Sonnet-only mode, ALL
model variables (including opus roles) get the sonnet bedrock string:

**`.claude/team-roles/architect.md`:**
- `{architect_model_personal}` -> planning model personal string
- `{architect_model_bedrock}` -> planning model bedrock string

**`.claude/team-roles/code-reviewer.md`:**
- `{reviewer_model_personal}` -> planning model personal string
- `{reviewer_model_bedrock}` -> planning model bedrock string

**`.claude/team-roles/pm.md`:**
- `{pm_model_personal}` -> planning model personal string
- `{pm_model_bedrock}` -> planning model bedrock string

**`.claude/team-roles/dev.md`:**
- `{dev_model_personal}` -> implementation model personal string
- `{dev_model_bedrock}` -> implementation model bedrock string
- `{dev_model_local}` -> local model string (or remove the line if N/A)

**`.claude/team-roles/qa.md`:**
- `{qa_model_personal}` -> implementation model personal string
- `{qa_model_bedrock}` -> implementation model bedrock string

**`QUICKSTART.md`:**
- `{lead_model}` -> planning model personal string
- `{lead_model_bedrock}` -> planning model bedrock string
- `{lead_model_string}` -> planning model string for the user's primary tier
- `{pm_model}` -> planning model personal string
- `{pm_model_bedrock}` -> planning model bedrock string
- `{architect_model}` -> planning model personal string
- `{architect_model_bedrock}` -> planning model bedrock string
- `{reviewer_model}` -> planning model personal string
- `{reviewer_model_bedrock}` -> planning model bedrock string
- `{dev_model}` -> implementation model personal string
- `{dev_model_bedrock}` -> implementation model bedrock string
- `{qa_model}` -> implementation model personal string
- `{qa_model_bedrock}` -> implementation model bedrock string

**`CLAUDE.md` Model Strategy table:**

If **Sonnet-only mode**, update the model strategy table to reflect
that all roles use sonnet:

```markdown
| Role          | Model  | Effort | Rationale                                              |
|---------------|--------|--------|--------------------------------------------------------|
| Lead          | sonnet | high   | Orchestration, validation cycles, gate checks          |
| PM            | sonnet | high   | Requirements elicitation and edge-case analysis        |
| Architect     | sonnet | high   | System design, tradeoff evaluation, ADRs               |
| Dev           | sonnet | medium | Implementation is high-volume, well-scoped by stories  |
| QA            | sonnet | medium | Test validation is pattern-matching against criteria   |
| Code Reviewer | sonnet | high   | Cross-cutting review needs architectural context       |
```

If **full model strategy**, leave the default table (opus for planning
roles, sonnet for implementation roles) unchanged.

**Sonnet-only mode — update CLAUDE.md prose references:**

If Sonnet-only mode was selected, also update these hardcoded model
tier references in `CLAUDE.md` to avoid misleading the agent:

- `Code Review (opus), QA functional validation (sonnet)` →
  `Code Review (sonnet, high effort), QA functional validation (sonnet)`
- In the Workflow phase table, replace `opus` with `sonnet` in the
  Model column for all phases, and `opus lead, sonnet dev` with
  `sonnet lead, sonnet dev`
- `Code Review (code-reviewer, opus)` →
  `Code Review (code-reviewer, sonnet)`
- `Code Review (opus) -- exhaustive` →
  `Code Review (sonnet, high effort) -- exhaustive`

These are prose references, not template variables. Use find-and-replace
to update them. This ensures the agent's instructions match its actual
model capabilities.

Context thresholds and auto-handoff mode are no longer template
variables in CLAUDE.md. They live in SKILL.md Handoff Protocol
section as defaults (yellow 80K / red 120K for 200K models;
yellow 120K / red 200K for 1M models; `auto_handoff_mode: off` by
default). Projects that need to override either MUST edit SKILL.md
directly. Do not prompt the user here.

---

## STEP 3: Deployment Configuration

Present what you detected in Step 1 about deployment. Then ask:

> **What is your deploy command?**
> (The command that builds and deploys to production.)
>
> Detected: [what you found, or "nothing detected"]
>
> Examples:
> - `docker compose build app && docker compose up -d app`
> - `vercel deploy --prod`
> - `kubectl apply -f k8s/`
> - `./scripts/deploy.sh production`
> - `npm run build && npm run deploy`

Wait for the user's answer.

> **What is your smoke test command?**
> (A command that tests the live deployed instance, not a dev server.)
>
> Detected: [what you found, or "nothing detected"]
>
> Examples:
> - `python3 -m pytest tests/test_smoke.py -v`
> - `npm run test:smoke`
> - `./scripts/smoke-test.sh`
> - `curl -sf https://your-app.com/health`

Wait for the user's answer.

Replace in these files:

**`CLAUDE.md`:**
- `{deploy_command}` (in the Deployment Commands section)
- `{smoke_test_command}` (in the Deployment Commands section)

**`.claude/skills/ai-dlc/steps/deploy-validate.md`:**
- `{deploy_command}` (in the Deploy section)
- `{smoke_test_command}` (in the Smoke Tests section)

**`.claude/skills/ai-dlc/steps/implementation.md`:**
- `{smoke_test_command}` (in the evidence requirements)

---

## STEP 4: Ownership Paths

Based on the directory scan from Step 1 — and any ownership paths
absorbed from archived team role files in Step 0 — propose ownership
assignments. If Step 0 found existing ownership paths, use those as the
starting proposal instead of generating from scratch.

**Dev ownership** should include application source directories, test
directories, and dependency files. Example:

```
- `src/` (application source code)
- `tests/` (unit and integration tests)
- `package.json` (dependency file, with lead approval for new dependencies)
```

**QA ownership** should include e2e/integration test directories and
test planning. Example:

```
- `tests/e2e/` (end-to-end tests)
- `tests/integration/` (integration tests)
- `docs/test-plans/`
```

Present your proposed ownership assignments and ask the user to confirm
or adjust. Format each as a markdown bullet list.

After confirmation, replace:

**`.claude/team-roles/dev.md`:**
- Replace the line `- {ownership_paths}` with the confirmed dev
  ownership list (one `- \`path/\`` line per directory)

**`.claude/team-roles/qa.md`:**
- Replace the line `- {qa_ownership_paths}` with the confirmed QA
  ownership list (one `- \`path/\`` line per directory)

---

## STEP 5: Operations Protocol

This section defines your project's deployment infrastructure rules in
`CLAUDE.md`. Based on Step 1 detection — and any infrastructure rules
absorbed from the archived CLAUDE.md in Step 0 — generate a scaffold.
If Step 0 found existing operations content, use it as the starting
draft and augment with AI/DLC-specific sections (pre-deploy checks,
rollback procedures) if missing.

**If Docker detected:**
```markdown
### Deployment

Default: `docker compose build <service> && docker compose up -d <service>`

### Pre-Deployment Checks
- Verify containers are healthy: `docker compose ps`
- Check disk space for builds

### Rollback
- `docker compose down <service> && docker compose up -d <service>` (uses previous image)
- For persistent data changes, restore from backup before restarting

### Service Restart Policy
- Restart individual services, not the entire stack
- Rebuilds require `docker compose build` before `up`
```

**If Kubernetes detected:**
```markdown
### Deployment
- `kubectl apply -f k8s/` for standard deploys
- Rollback: `kubectl rollout undo deployment/<name>`

### Pre-Deployment Checks
- Verify cluster health: `kubectl get nodes`
- Check pending migrations
```

**If serverless (Vercel/Netlify/Fly) detected:**
```markdown
### Deployment
- Automatic on push to main (or manual via CLI)
- Rollback: redeploy previous commit

### Pre-Deployment Checks
- Verify environment variables are set in dashboard
- Run build locally before deploying
```

**If nothing detected:**
```markdown
### Deployment
<!-- TODO: Define your deployment command and process -->

### Pre-Deployment Checks
<!-- TODO: Define checks to run before deploying -->

### Rollback
<!-- TODO: Define how to rollback a failed deployment -->
```

Present the scaffold and ask: "Here's a draft operations protocol based
on your project. Edit as needed, or confirm to use as-is."

After confirmation, replace `{project_operations_protocol}` in
`CLAUDE.md` with the confirmed content.

---

## STEP 6: Launch Configuration

Generate a shell function based on the project name and API tier.
**This is documentation only** — write it to `QUICKSTART.md` as a
reference. Do NOT modify the user's shell profile (`.zshrc`,
`.bashrc`, etc.). The user can copy it to their profile themselves
if they choose to.

**Template:**

```bash
# AI/DLC launch function
# Copy to your shell profile (~/.zshrc, ~/.bashrc, etc.) if desired

claude-PROJECT_NAME() {
  ANTHROPIC_MODEL=LEAD_MODEL \
  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 \
  claude --dangerously-skip-permissions "$@"
}
```

For **Personal** tier:
- `LEAD_MODEL` = opus personal string

For **Bedrock** tier, add AWS environment variables:
```bash
claude-PROJECT_NAME() {
  ANTHROPIC_MODEL=LEAD_MODEL \
  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 \
  CLAUDE_CODE_USE_BEDROCK=1 \
  AWS_REGION=us-east-1 \
  claude --dangerously-skip-permissions "$@"
}
```

For **Both** tiers, generate two functions (e.g.,
`claude-PROJECT_NAME` and `claude-PROJECT_NAME-bedrock`).

Derive `PROJECT_NAME` from the project directory name or `package.json`
name field. Convert to lowercase kebab-case.

Present the generated function(s) and tell the user:
"This launch function has been added to QUICKSTART.md for reference.
Copy it to your shell profile if you'd like to use it."

Replace `{launch_configuration}` in `QUICKSTART.md`.

---

## STEP 7: Coding Conventions

Configure the project-specific sections in `docs/coding-conventions.md`.
For each placeholder, auto-detect what you can and present a proposal.
If Step 0 absorbed content from an archived `coding-conventions.md`,
use that as the starting proposal for each relevant sub-section rather
than generating from scratch. Present absorbed content with a note:
"(from your existing coding-conventions.md)" so the user knows the
source.

### 7a: General Conventions (`{project_general_conventions}`)

Based on detected language/framework, propose conventions. Examples:

**TypeScript/JavaScript:**
```markdown
- Use TypeScript strict mode. No `any` types in production code.
- Prefer `const` over `let`. Never use `var`.
- Use named exports, not default exports.
- Format with Prettier (run via lint command).
```

**Python:**
```markdown
- Type hints required on all function signatures.
- Use `Decimal` for financial/precision-critical math, never `float`.
- Format with black. Lint with ruff.
```

**Go:**
```markdown
- Follow standard library conventions.
- Wrap errors with `fmt.Errorf("context: %w", err)`.
- Use table-driven tests.
```

Present your proposal. Ask the user to confirm, modify, or replace.
If the user says "skip" or "none for now", leave the HTML comment in
place and remove the placeholder text. This section can be filled in
later.

Replace `{project_general_conventions}` (the text between the HTML
comment and the next `---` divider) with the confirmed content.

### 7b: API Conventions (`{project_api_conventions}`)

Based on detected API layer:

**If GraphQL:** Propose schema verification language and codegen conventions.
**If REST:** Propose versioning and OpenAPI sync rules.
**If neither:** Ask the user if they have API conventions, or skip.

Replace `{project_api_conventions}` with confirmed content.

### 7c: Story Conventions (`{project_story_conventions}`)

Ask: "Do you have domain-specific story conventions? (e.g., accessibility
requirements, interaction patterns, i18n rules). If not, we can skip
this section."

Replace `{project_story_conventions}` with confirmed content, or
remove the placeholder if skipped.

### 7d: Review Conventions (`{project_review_conventions}`)

Ask: "Do you have additional code review conventions beyond what's
already in the template? (e.g., performance benchmarks, security
scanning requirements). If not, we can skip."

Replace `{project_review_conventions}` with confirmed content, or
remove the placeholder if skipped.

### 7e: Impact Classification (`{impact_classification_table}`)

Generate a table based on detected stack:

```markdown
| Change Type | Cost / Reversibility | Minimum Planning Level |
|---|---|---|
| Documentation | Zero cost, instantly reversible | Commit directly |
| Config files | Near-zero cost, instantly reversible | Commit directly |
| Application code | Low cost, redeploy ~N min | Planned story |
```

Add rows based on detection:
- **If database detected:** `| Database schema | High cost, migration required | Story + migration plan |`
- **If Docker/K8s:** `| Infrastructure | Varies by resource | Story + architecture review |`
- **If CDN/static assets:** `| CDN/static assets | Low cost, cache invalidation delay | Planned story |`

Present and ask for confirmation.

Replace `{impact_classification_table}` in `docs/coding-conventions.md`.

### 7f: High-Cost Action Gates (`{high_cost_action_gates}`)

Generate based on detected stack:

```markdown
The following operations require a planned story or explicit user
approval before execution:

- **Database destructive operations** (DROP, TRUNCATE, DELETE without
  WHERE) — requires planned story with rollback plan
- **Force push / reset --hard** — requires lead approval
- **Dependency major version upgrades** — requires planned story
```

Add rows based on detection:
- **If Docker:** `- **Full stack rebuild** (docker compose build --no-cache) — requires lead approval (takes N minutes)`
- **If K8s:** `- **Node scaling / cluster changes** — requires explicit user approval`
- **If CI/CD:** `- **CI/CD pipeline modifications** — requires architecture review`

Present and ask for confirmation.

Replace `{high_cost_action_gates}` in `docs/coding-conventions.md`.

---

## STEP 8: Pattern Selection

Present the available enforcement patterns with recommendations based
on the project scan:

```
## Available Patterns

Patterns are optional enforcement modules. Install the ones relevant
to your project.

1. **GraphQL Schema Verification**
   When: Project queries a GraphQL API
   Detected: [YES/NO based on scan]
   Recommendation: [INSTALL / SKIP]

2. **Computation Plausibility Validation**
   When: Project computes derived values (financial, analytics, metrics)
   Detected: [MAYBE — ask user]
   Recommendation: [ASK]

3. **API Field Verification for UI**
   When: Frontend consumes and displays API data
   Detected: [YES/NO based on scan]
   Recommendation: [INSTALL / SKIP]

4. **High-Cost Action Gating**
   When: Project has expensive/irreversible operations
   Detected: [YES/NO based on scan]
   Recommendation: [INSTALL / SKIP]

5. **Bundle Verification**
   When: Frontend has a build pipeline producing minified assets
   Detected: [YES/NO based on scan]
   Recommendation: [INSTALL / SKIP]
```

Ask: "Which patterns do you want to install? (Enter numbers, e.g.,
'1, 3, 5', or 'none')"

For each selected pattern, read the pattern file from
`docs/ai-dlc-patterns/` (copied there by install.sh) and configure it:

### Pattern: GraphQL Schema Verification
Ask:
- "What is your GraphQL introspection query?"
  Example: `{ __type(name: "Pool") { fields { name } } }`
- "What is your GraphQL endpoint (or env var)?"
  Example: `$GRAPH_ENDPOINT`

Append the configured block to `docs/coding-conventions.md` under the
API conventions section.

### Pattern: Computation Plausibility Validation
Ask:
- "What computed values does your project produce?"
  Examples: "APR, fees, totals" or "conversion rates, percentiles"
- "What tolerance is acceptable?"
  Examples: "0.01% for ratios" or "0.001 absolute"

Append the configured block to `docs/coding-conventions.md` under
production integrity tests.

### Pattern: API Field Verification for UI
No additional variables needed. Append the convention block to
`docs/coding-conventions.md` and the severity classification to
`.claude/team-roles/code-reviewer.md`.

### Pattern: High-Cost Action Gating
Ask:
- "List your project's high-cost operations and their classification."

The user's answer populates `{impact_classification_rows}`. Merge
with the impact classification table from Step 7e.

### Pattern: Bundle Verification
Ask:
- "What is the URL pattern for your deployed bundles?"
  Example: `https://your-app.com/static/js/main.*.js`
- "What verification command should be used?"
  Example: `curl -s <url> | grep -c 'expected-selector'`

Append the configured block to `docs/coding-conventions.md`.

---

## STEP 9: Validation Sweep

Run a comprehensive check for remaining template variables:

```bash
grep -rn '{[a-z_]*}' .claude/skills/ai-dlc/ .claude/team-roles/ CLAUDE.md QUICKSTART.md docs/coding-conventions.md 2>/dev/null | grep -v '{project-root}' | grep -v '<!--'
```

**If matches found:**
- Show each remaining variable to the user
- For each, either resolve it (if you have enough context) or ask
- Repeat the sweep until zero matches remain

**If no matches:**
- Report: "All template variables have been configured."

---

## STEP 10: Summary

**If this was a full setup run**, present a complete summary:

```
## AI/DLC Configuration Complete

### API Tier
[Personal / Bedrock / Both]

### Models
| Role | Model String |
|------|-------------|
[table of role -> model string for the user's primary tier]

### Deployment
- Deploy: `[command]`
- Smoke test: `[command]`

### Ownership
- Dev: [directories]
- QA: [directories]

### Patterns Installed
[list, or "none"]

### Conventions Configured
[list of sections that were filled in vs. skipped]

### Validation
All template variables replaced. Zero `{variable}` placeholders
remaining (excluding `{project-root}` runtime variable).

## Next Steps

1. Review the generated files:
   - `CLAUDE.md` — project intelligence and autonomy rules
   - `QUICKSTART.md` — reference documentation
   - `docs/coding-conventions.md` — coding standards
2. Optionally copy the launch function from QUICKSTART.md to your shell profile
3. Run `/ai-dlc` with a description to start your first pipeline
```

**If this was a single-section update** (via argument or menu selection),
present a scoped summary covering only what was changed:

```
## Updated: [Section Name]

[Brief description of what was configured/changed]

### Validation
[Result of the validation sweep — any remaining variables, or all clear]
```
