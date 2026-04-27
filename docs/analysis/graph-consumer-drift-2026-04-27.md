# Graph consumer drift analysis — 2026-04-27

Source: `~/git/graph/.claude/{skills/ai-dlc,skills/ai-dlc-setup,team-roles,hooks}`
Target: `~/git/ai-dlc` distribution, currently at `VERSION=0.2.0`.

## Summary

- Consumer has **no `.claude/.ai-dlc-version` stamp** — predates 0.2.0 install, or was installed without running `scripts/install.sh`. Drift-check script cannot function.
- Consumer `research-citations.md` is **missing** from `.claude/skills/ai-dlc/` (added to distribution after consumer install).
- Patterns, hooks, setup SKILL, and 11/18 step files are **byte-identical**.
- **8 content-bearing divergences** to classify: 7 are consumer additions carrying new sprint-retro PI rules (PI-S169-*, PI-S170-*); 1 is the SKILL.md handoff-protocol regression where consumer is **older** than distribution.

## Direction of drift per file

| File | Diff | Consumer newer? | Kind |
|---|---|---|---|
| `skills/ai-dlc/SKILL.md` | 62 lines | **No — dist newer (04-26 15:38 vs 04-26 02:12)** | Consumer missing upstream 4→5 step handoff + `----`-delimiter rework (ai-dlc commit `06ffb5f`) |
| `skills/ai-dlc/steps/carry-over-evaluation.md` | +18 | Yes | New sections PI-S169-8 audit-anchor read, PI-S170-2 subgraph prune check |
| `skills/ai-dlc/steps/deploy-validate.md` | +54 / −2 | Yes | PI-S170-2 `_meta` probe, PI-S170-6 live-UI magnitude, PI-S169-2 sprint-overall PR pre-staging; also graph-specific `gh pr merge --squash`, `SPRINT_ID`, `SMOKE_DEPLOY_VALIDATE`, `SMOKE_EVIDENCE_DIR` wiring |
| `skills/ai-dlc/steps/gate-validation.md` | +68 / −17 | Mixed | Adds: Check 18 per-class test-debt, Check 19 self-reflexive Gate 2 discrimination, PI-S170-8 duplicate parent-key drift. Deletes: upstream's 5-step handoff procedure (same regression as SKILL.md) |
| `skills/ai-dlc/steps/implementation.md` | +11 / −1 | Yes | PI-S169-6 protected-path `lead_only` enforcement. Template-var regression: `{smoke_test_command}` → hard-coded `scripts/test-aws-smoke.sh` |
| `skills/ai-dlc/steps/retro.md` | +9 | Yes | Step 5b PI-S169-8 audit-anchor SHA append |
| `skills/ai-dlc/steps/sprint-review.md` | +10 | Yes | PI-S169-2 sprint-overall PR incremental pre-staging |
| `skills/ai-dlc/steps/stories-test-strategy.md` | +39 | Yes | PI-S169-6 protected-path story tag + catalog; PI-S169-7 layered AC verification accounting |
| `team-roles/architect.md` | +2 / 0 | Substitution | Template vars resolved (`{architect_model_*}`) |
| `team-roles/pm.md` | +2 / 0 | Substitution | Same |
| `team-roles/qa.md` | +6 / −6 | Substitution | Template vars + graph-specific ownership paths |
| `team-roles/dev.md` | +11 / −8 | Substitution | Template vars + graph-specific ownership paths (graph-node-src, subgraph, server, etc.) |
| `team-roles/code-reviewer.md` | +98 | Yes | Template vars resolved; **also** adds PI-S170-3 token-conservation test mandate, PI-S170-4 bug-class audit mandate, PI-S170-2 `_meta` probe evidence, full Self-Discrimination Map section (Patterns 1/2/3) referenced by Check 19 |

## Upstream absorption candidates

### Tier A — generalized mechanisms, high reuse
Portable across any ai-dlc consumer. Recommend absorbing verbatim or lightly generalized.

1. **Audit-anchor SHA chain (PI-S169-8).** retro.md Step 5b producer + carry-over-evaluation.md 1a reader + gate-validation.md Check 18. Connects sprint-N retro PR SHA to sprint-N+1 per-class test-debt audit. Generic mechanism; not graph-specific. Requires new `templates/audit-anchors.md.template`.
2. **Self-reflexive Gate 2 self-discrimination map (PI-S169-5).** gate-validation.md Check 19 + code-reviewer.md three-pattern map. General anti-fabrication enforcement for reviewer. Not graph-specific. Large (98-line code-reviewer addition).
3. **Duplicate parent-key drift check (PI-S170-8).** gate-validation.md. Catches parallel-worktree structural drift in sprint-status.yaml. General.
4. **Sprint-overall PR incremental pre-staging (PI-S169-2).** sprint-review.md + deploy-validate.md verification. Prevents post-hoc composition. General.
5. **Protected-path story tag (PI-S169-6).** stories-test-strategy.md catalog + tag fields + implementation.md lead-only enforcement. Catalog is consumer-specific but the **mechanism** (`lead_only`, `single_dev_serialized`, `protected_paths`) is general. Template the catalog; ship the fields.
6. **Layered AC verification accounting (PI-S169-7).** stories-test-strategy.md. Layer enum (unit/integration/e2e/live_ops/manual_operator) + `layered_ac_count` frontmatter. General.
7. **Bug-class audit mandate (PI-S170-4).** code-reviewer.md. "Class-of-bug fix requires grep-derived enumeration of same-shape call-sites." General; domain-neutral.

### Tier B — domain-specific but pattern-worthy
Not portable verbatim. Could become new `patterns/` entries.

8. **Token-conservation invariant test (PI-S170-3).** code-reviewer.md. Specific to financial-IL aggregation. Candidate for `patterns/token-conservation-invariant.md` (generalizes `financial-plausibility.md`).
9. **Subgraph time-travel `_meta` probe + `indexerHints.prune` retention (PI-S170-2).** carry-over-evaluation.md + deploy-validate.md + code-reviewer.md. Subgraph-only. Candidate for `patterns/subgraph-time-travel-retention.md`.
10. **Live-UI magnitude sanity check (PI-S170-6).** deploy-validate.md. Specific to financial dashboards. Candidate for extending `patterns/financial-plausibility.md`.

### Tier C — consumer-only, do not absorb
- Team-role template-variable resolution (architect/pm/qa/dev/code-reviewer model switches, ownership paths). Expected consumer-install behavior.
- `gh pr merge --squash` deploy command, `test-aws-smoke.sh`, `SPRINT_ID`/`SMOKE_DEPLOY_VALIDATE`/`SMOKE_EVIDENCE_DIR` hard-codes in deploy-validate.md and implementation.md. These replaced `{deploy_command}`/`{smoke_test_command}` template vars — **regression** in template usage, consumer-only.

## Regressions / issues to flag

- **Consumer is behind on handoff protocol.** SKILL.md + gate-validation.md still carry the pre-`06ffb5f` 4-step handoff; distribution has the 5-step variant with TaskStop-first and `----` delimiters. Consumer should pull upstream, not vice-versa.
- **Template-var regression.** `implementation.md` and `deploy-validate.md` have hard-coded graph commands where templates existed. Not a distribution problem but worth noting if the install flow is supposed to preserve `{smoke_test_command}` substitution markers.
- **No `.ai-dlc-version` stamp.** Consumer cannot use `scripts/check-version.sh`. Either install predates 0.2.0 or install was manual. Operator should run `scripts/install.sh` to seed the stamp.
- **Missing `research-citations.md`.** Distribution added; consumer never pulled. Confirms consumer is pre-sync.

## Recommended operator actions

1. Decide Tier A absorption (7 items). Each is bounded and independently landable. Suggest 0.3.0 MINOR bump for the batch (additive, no breaking consumer-visible interface change).
2. Tier B (3 items) → evaluate as candidate patterns; may or may not warrant upstreaming depending on how domain-specific the distribution wants to be.
3. Tier C — no action.
4. Reverse sync: consumer needs to pull distribution's `06ffb5f` handoff rework + add the `.ai-dlc-version` stamp + add `research-citations.md`.
5. Future: when absorbing Tier A, introduce template vars for domain-specific pieces (e.g., protected-path catalog, subgraph details) so graph-specific overrides land at install time, not as diff drift.
