# Changelog

All notable changes to AI/DLC are recorded here.

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
and [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Bump rules

- **MAJOR** — breaking change to skill contract, hook protocol, gate-validation
  schema, install layout, or any consumer-visible interface that requires
  manual migration. Pre-1.0, breaking changes may land in MINOR.
- **MINOR** — additive: new steps, new patterns, new validation checks, new
  hook capabilities, new templates. Existing consumers keep working without
  migration.
- **PATCH** — wording, doc fixes, internal cleanup, non-behavioral edits.

## [Unreleased]

## [0.2.0] — 2026-04-26

### Changed

- Rule 2(a) human-requested handoff and the auto-handoff helper
  (`gate-validation.md` "Auto-handoff evaluation") are now 5-step
  procedures. New Step 1 stops all in-flight teammates (TaskStop on
  every `in_progress` task plus halt of any Agent-spawned teammate
  not bound to a task) BEFORE committing in-flight work, finalizing
  the snapshot, or emitting the resume prompt. Closes a race where
  teammates kept running after the lead output the resume prompt
  and committed work the successor session could not see.
- Resume prompt template in `core/skills/ai-dlc/SKILL.md` Handoff
  Protocol is now wrapped in `----` delimiter lines (one before,
  one after) so the user knows exactly which lines to copy/paste
  into the new session. Auto-handoff procedure references the same
  delimiter requirement.

[0.2.0]: https://github.com/euron8/ai-dlc/releases/tag/v0.2.0

## [0.1.0] — 2026-04-25

Initial versioned release. Establishes the public surface for change tracking.

### Added

- `VERSION` file at repo root as semver source of truth.
- `CHANGELOG.md` for release history.
- `scripts/install.sh` writes `.claude/.ai-dlc-version` stamp into the
  consumer project at install time, capturing the installed version,
  upstream commit sha, and install timestamp. Consumers can read this
  file to know what they have.
- `scripts/check-version.sh` — consumer-runnable script that compares
  the local stamp against the upstream `VERSION` file and reports drift.
- README "Versioning" section documenting bump rules and the consumer
  upgrade flow.

### Baseline

The 0.1.0 line freezes the current shape of:

- `core/skills/ai-dlc/` (SKILL.md + 18 step files)
- `core/skills/ai-dlc-setup/SKILL.md`
- `core/team-roles/{architect,code-reviewer,dev,pm,qa}.md`
- `core/hooks/ai-dlc-{protect,pause,continue}.sh`
- `core/scripts/validate-{ci-gates,provenance-block,mandatory-rules,retro-evidence}.sh`
- `core/ci-templates/validate-{ci-gates,retro-compliance}.yml`
- `core/fixtures/check-{15-bypass,17-bypass,h1-recursion,1c-bypass}/`
- `patterns/` (high-cost-action-gating, bundle-verification,
  api-field-verification, financial-plausibility, ...)
- `templates/{CLAUDE.md,QUICKSTART.md,settings.json,coding-conventions.md}.template`

[Unreleased]: https://github.com/euron8/ai-dlc/compare/v0.2.0...HEAD
[0.1.0]: https://github.com/euron8/ai-dlc/releases/tag/v0.1.0
