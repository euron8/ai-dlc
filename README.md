# AI/DLC — AI Development Lifecycle

Autonomous development pipeline for Claude Code + BMAD Method.
Single conversation from idea to production deployment.

## What it does

`/ai-dlc` orchestrates the full software development lifecycle:
planning, architecture, implementation, testing, code review, QA,
deployment, and retrospective — autonomously in one conversation.

**9 pipeline variants** auto-detected from project state:
- Greenfield, Feature, Bug fix, Carry-over sprint, Sprint execution
- Brownfield A/B/C (mid-implementation, full analysis, doc validation)
- Analysis-only (no implementation)

**Structural enforcement** at every phase:
- 19+ gate validation checks including harness meta-checks (not advisory — gates fail if violated)
- LOCKED_REQUIREMENTS anchoring (prevents requirement drift)
- Three-tier escalation (HARD_BLOCK, DECIDED_AUTONOMOUSLY, DEFERRAL_REQUEST)
- Evidence-producing mandatory checks (dev, code review, QA)
- Production integrity tests as a hard gate
- Retro improvements applied at all 5 enforcement layers
- Minimum-mechanism mandate (KISS, Rule 26) — over-engineering is a
  review finding class; retro audits remove guard machinery that
  catches nothing

## Prerequisites

- [Claude Code](https://github.com/anthropics/claude-code) with Agent Teams enabled
- [BMAD Method v6](https://github.com/bmad-code-org/BMAD-METHOD) installed
  (`npx bmad-method install` with BMM, CIS, TEA modules)
- [context-mode](https://github.com/kianwoon/context-mode) plugin
  installed (`claude mcp add-plugin context-mode`) — **required**. Provides
  the sandbox execution (`ctx_*`) that AI/DLC routes large reads and batch
  operations through to keep raw bytes out of the resident context. The
  install enables it (`settings.json` `enabledPlugins`) and wires the
  protection hook (`ai-dlc-protect.sh`) that prevents context-mode from
  consolidating rule files that must load verbatim.

### Required environment for autonomous execution

AI/DLC runs autonomously — agents edit files, execute commands, spawn
teammates, and deploy without human approval at each step. This
requires two environment settings:

```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

And launching Claude Code with `--dangerously-skip-permissions`:

```bash
claude --dangerously-skip-permissions
```

**Without these, the pipeline will stall** at every file write, shell
command, and teammate spawn waiting for manual approval — breaking the
autonomous flow.

**Option: create a launch function** for convenience. Add to your
shell profile (`~/.zshrc`, `~/.bashrc`, etc.):

```bash
claude-myproject() {
  ANTHROPIC_MODEL=claude-opus-4-6[1m] \
  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 \
  claude --dangerously-skip-permissions "$@"
}
```

Replace `myproject` with your project name and adjust the model string
for your environment (see `QUICKSTART.md` for Bedrock variants).

**What `--dangerously-skip-permissions` means:** Agents can execute
any shell command, edit any file, and make network calls without
confirmation. Risk is mitigated by ownership boundaries in team role
files, the lead's orchestration, gate validation, and git (work on a
branch). If you are not comfortable with blanket permissions, you can
omit the flag and approve each action manually, but expect significant
interruption to the autonomous flow.

## Install

```bash
git clone https://github.com/euron8/ai-dlc.git
cd ai-dlc
./scripts/install.sh /path/to/your-project
```

The installer copies core files, creates directory structure, and
generates templates. It also installs:
- Protection hook (`.claude/hooks/ai-dlc-protect.sh`)
- Validation scripts (`scripts/validate-*.sh`)
- CI workflow templates (if `.github/workflows/` exists)
- Test fixture scaffolding (`tests/fixtures/`)
- The `ai-dlc-update` skill (the distribution→consumer pull path)

### Adopting `ai-dlc-update` on an older install

Consumers installed before `ai-dlc-update` existed do not have the skill, and
its first landing cannot go through `install.sh` — that overwrite is exactly
what `ai-dlc-update` exists to avoid. Land it additively instead (touches
nothing else in the consumer, leaves the version stamp intact):

```bash
./scripts/bootstrap-update-skill.sh /path/to/your-project
```

Then run `/ai-dlc-update` in the consumer (bare = dry-run report; add `apply`
to land). The skill self-updates thereafter, so this is a one-time step. Fresh
installs already include the skill and skip this.

If your project already has `CLAUDE.md`, team roles, or coding
conventions, the installer archives them to `docs/pre-ai-dlc/`
before replacing. The `/ai-dlc-setup` wizard reads the archived
files and absorbs your project-specific content (ownership paths,
model strings, conventions, infrastructure rules) into AI/DLC's
templates during configuration.

## Uninstall

```bash
./scripts/uninstall.sh /path/to/your-project
```

Removes all AI/DLC skills, team roles, templates, hooks, validation
scripts, CI workflows, and fixture templates. Preserves your planning
artifacts (`_bmad-output/`), code reviews, and retrospectives. Add
`--force` to skip confirmation.

## Configure

**Recommended:** Run the guided setup wizard in Claude Code:

```
/ai-dlc-setup
```

The wizard scans your project, auto-detects settings, asks targeted
questions, replaces all template variables, selects enforcement
patterns, and validates the result.

**Manual alternative:** Search for `{template_variable}` placeholders:

```bash
grep -rn '{[a-z_]*}' .claude/skills/ai-dlc/ .claude/team-roles/
```

Key variables:

| Variable | What to set |
|----------|------------|
| `{deploy_command}` | Your deployment command |
| `{smoke_test_command}` | Your smoke/integration test command |
| `{model_personal}` | Model string for your Claude environment |
| `{model_bedrock}` | Model string for Bedrock (if using) |
| `{ownership_paths}` | Source directories per team role |

## Use

```
/ai-dlc Build a user dashboard with real-time metrics
```

Effort levels are set automatically — `high` for the lead and planning
roles, `medium` for implementation roles. No manual `/effort` needed.

The pipeline auto-detects the variant and runs to completion. The only
human checkpoint is production validation after deployment. The retro
runs at the end with a pause for your commentary.

## Patterns

Optional enforcement modules that add gate checks for specific project
characteristics. The installer copies pattern files to
`docs/ai-dlc-patterns/` in your project for reference.

| Pattern | Use when |
|---------|----------|
| `graphql-schema-verification` | Project queries GraphQL APIs |
| `financial-plausibility` | Project computes derived values |
| `api-field-verification` | Frontend consumes API data |
| `high-cost-action-gating` | Project has expensive/irreversible operations |
| `bundle-verification` | Frontend has a build pipeline |

**Recommended:** `/ai-dlc-setup` (Step 8) walks you through pattern
selection and configures everything automatically.

**Manual installation** for each pattern you want:

1. Open the pattern file in `docs/ai-dlc-patterns/<pattern>.md`
2. Copy the markdown block from the **Configuration** section
3. Paste it into `docs/coding-conventions.md` under the appropriate
   section (the pattern file tells you where)
4. Replace the pattern's template variables with your project values
   (listed under **Template variables** in the pattern file)
5. If the pattern specifies additions to `code-reviewer.md`, add those
   to `.claude/team-roles/code-reviewer.md` as well

## Project Structure

```
your-project/
  .claude/
    hooks/
      ai-dlc-pause.sh             # Rule 3 pause-point enforcement
      ai-dlc-continue.sh          # Rule 3 continuation mandate
      ai-dlc-driver-signal.sh     # Auto session-chaining signal
      ai-dlc-protect.sh           # Context-mode verbatim-load protection
    skills/ai-dlc/
      SKILL.md                    # Entry point (Rules 1-20)
      steps/                      # 18 pipeline step files
    skills/ai-dlc-setup/
      SKILL.md                    # Guided configuration wizard
    skills/ai-dlc-update/         # distribution->consumer pull path (reconcile)
      SKILL.md
      reconcile/                  # per-block classifier + preclassify engine
    team-roles/                   # 5 role definitions
  CLAUDE.md                       # Project config (autonomy rules live in SKILL.md)
  QUICKSTART.md                   # Reference documentation
  scripts/
    validate-provenance-block.sh  # Provenance block validator
    validate-retro-evidence.sh    # Retro transcript + SHA enforcement
    validate-mandatory-rules.sh   # Combined mandatory rule validator
    validate-ci-gates.sh          # Dormant gate detector
  tests/fixtures/                 # Adversarial self-test fixtures
  docs/
    coding-conventions.md         # Project coding standards
    ai-dlc-feedback.md            # Feedback loop log
    escalations/pending.md        # Escalation file
    reviews/                      # Code review output
    retro/                        # Sprint retrospectives
  _bmad-output/
    planning-artifacts/           # Briefs, PRDs, stories
    implementation-artifacts/     # Gate log, sprint status
    party-mode-transcripts/       # Retro party-mode transcripts
```

## Architecture

Three layers:

**Core** — Universal pipeline logic. Gate validation (19+ checks
including harness meta-checks), escalation model (3 tiers),
requirement anchoring, autonomy rules (19, in SKILL.md), session
model, team roles, validation scripts, pipeline hooks, context-mode
protection hook. Does not change per project.

**Patterns** — Reusable enforcement modules. Each pattern is a
generalizable gate check with a configuration interface. Install the
ones your project needs.

**Project Config** — Your deployment commands, test commands, file paths,
thresholds, conventions. Stays in your project, never flows upstream.

## Feedback Loop

When your project discovers a new failure mode:

1. Add a project-specific rule to handle it
2. Log it in `docs/ai-dlc-feedback.md` with the generalizability assessment
3. During retro, review the feedback log
4. If generalizable, extract the pattern and contribute upstream
5. Replace your project-specific rule with the pattern + config

This ensures lessons learned in one project benefit all projects using
AI/DLC, without project-specific details leaking into the core.

## Working on the distribution

Enable the gate, once per clone:

```sh
git config core.hooksPath .githooks
```

`.githooks/pre-push` runs the distribution's validators against the distribution:
enforcement-map integrity (I1–I9), the `SKILL.md` re-attach budget, the full fixture
suite, and `bash -n` over every shipped script. It blocks the push on a failure.

**There is no GitHub Actions CI, deliberately** — not here and not in the reference
consumer. The gate runs on the machine doing the pushing: no runner, no network, no
third party. `git push --no-verify` bypasses it, and that is a decision made on the
record rather than a default fallen into.

This exists because ai-dlc shipped fifteen validators and a CI template *to its
consumers* while gating none of its own. Every check ran only when a human remembered
to type it, and that is how three releases shipped half-wired: the enforcer named, and
never invoked.

## Versioning

AI/DLC follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The current release is recorded in [`VERSION`](VERSION); release notes
live in [`CHANGELOG.md`](CHANGELOG.md).

**Bump rules:**

- **MAJOR** — breaking change to the skill contract, hook protocol,
  gate-validation schema, install layout, or any consumer-visible
  interface that requires manual migration. Pre-1.0, breaking changes
  may land in MINOR.
- **MINOR** — additive: new steps, new patterns, new validation checks,
  new hook capabilities, new templates. Existing consumers keep working
  without migration.
- **PATCH** — wording, doc fixes, internal cleanup, non-behavioral edits.

**For consumers:** `scripts/install.sh` writes a stamp at
`.claude/.ai-dlc-version` in your project, capturing the installed
version, upstream commit sha, and install timestamp. To detect drift
from upstream, run from your project root:

```bash
<path-to-ai-dlc>/scripts/check-version.sh
```

It compares your stamp against the upstream `VERSION` on `main` and
prints either "Up to date" or the drift delta with a link to the
changelog. Re-run `install.sh` to upgrade.

## License

Apache License 2.0 — see [LICENSE](LICENSE).
