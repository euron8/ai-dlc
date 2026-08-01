# Goal 2 triage worksheet — graph, measured 2026-08-01 at `56927c419`

Produced in `ai-dlc`, read-only, to make §6c-31 a REVIEW job rather than a discovery job.
**The consumer is the authority on every line below.** Core cannot decide these — that is the
undecidable question eight refuted predicates established — so this is a starting point with its
reasoning shown, not an answer.

## The test, applied per file

**If ai-dlc were removed from this repository tomorrow, would this script still have a job?**
Yes -> consumer-owned domain code, it STAYS where it is and does NOT enter the inventory.
No -> ai-dlc machinery, it moves to `scripts/ai-dlc-local/` and is declared.

## Corpus and controls

| measure | reading |
|---|---|
| consumer-authored `.sh`/`.py` outside the home | **836** |
| naming an ai-dlc artifact (`_bmad-output`, `push-candidate-ledger`, `gate-validation`, `ai-dlc`) | **142** |
| control — pure-domain token (`cloudformation`/`terraform`) | 21 |
| control — nonsense token | 0 |

## TIER 1 — machinery by the charter's own naming. No judgement needed.

These six are charter Part F's consumer-machinery list. This program spent goal 5 measuring them
as ai-dlc machinery. **Confirm and move.**

- [ ] `scripts/scan-stray-provenance.sh` — 83 lines
- [ ] `scripts/audit-rule-exercise.sh` — 105 lines
- [ ] `scripts/generate-sprint-status.py` — 1068 lines
- [ ] `scripts/audit-main-since.sh` — 364 lines
- [ ] `scripts/validate-no-direct-main-push.sh` — 46 lines
- [ ] `scripts/retro-replay-harness.sh` — 97 lines

## TIER 2 — `scripts/tests/` naming an ai-dlc artifact (45 files)

Near-certain machinery: these are the gate tests for ai-dlc rules and checks. Review as a block.

- [ ] `scripts/tests/run-discrimination-matrix.sh`
- [ ] `scripts/tests/run-escalation-status-vocabulary-fixture-test.sh`
- [ ] `scripts/tests/test_normalize_backlog_status.py`
- [ ] `scripts/tests/test_s280_1_close_sweep.py`
- [ ] `scripts/tests/test_sprint_status_per_sprint.py`
- [ ] `scripts/tests/test_ssl_flake_instrumentation.py`
- [ ] `scripts/tests/test_validate_il_revalidation.py`
- [ ] `scripts/tests/test_validate_phase_sequencing.sh`
- [ ] `scripts/tests/test_validate_retro_evidence_sha.sh`
- [ ] `scripts/tests/test-audit-rule-files.sh`
- [ ] `scripts/tests/test-audit-squash-enum.sh`
- [ ] `scripts/tests/test-check18-debt-audit.sh`
- [ ] `scripts/tests/test-guarded-merge.sh`
- [ ] `scripts/tests/test-handoff-request-vs-noun-discrimination.sh`
- [ ] `scripts/tests/test-handoff-resume-format.sh`
- [ ] `scripts/tests/test-pr-class-provenance-in-non-retro.sh`
- [ ] `scripts/tests/test-pr-class-retro-precedence.sh`
- [ ] `scripts/tests/test-pr-class-sprint-review-transcript.sh`
- [ ] `scripts/tests/test-rule-ref-reconcile.sh`
- [ ] `scripts/tests/test-s239-1-hardening.sh`
- [ ] `scripts/tests/test-s239-2-check26-discrimination.sh`
- [ ] `scripts/tests/test-s241-5-ac4-provenance-secret.sh`
- [ ] `scripts/tests/test-s241-5-gate3-tamper.sh`
- [ ] `scripts/tests/test-s259-4-check30-orphaned-fn.sh`
- [ ] `scripts/tests/test-s262-1-pathgate-exclusion.sh`
- [ ] `scripts/tests/test-s262-check31-cited-sha.sh`
- [ ] `scripts/tests/test-s275-filewrite-convention.sh`
- [ ] `scripts/tests/test-s280-1-close-sweep-teeth.sh`
- [ ] `scripts/tests/test-s280-2-migrate-dryrun.sh`
- [ ] `scripts/tests/test-s288-1-check5-registration-teeth.sh`
- [ ] `scripts/tests/test-s288-2-ci-checks-repoint.sh`
- [ ] `scripts/tests/test-s289-3-ci-gates.sh`
- [ ] `scripts/tests/test-s292-3-validator-runs-arity.sh`
- [ ] `scripts/tests/test-scan-stray-legit-homes.sh`
- [ ] `scripts/tests/test-sprint-status-consumer-cutover.sh`
- [ ] `scripts/tests/test-validate-story-status-consistency.sh`
- [ ] `scripts/tests/validate-mandatory-rules/fixture-false-positive-ac-text/test.sh`
- [ ] `scripts/tests/validate-mandatory-rules/fixture-lead-self-executed/test.sh`
- [ ] `scripts/tests/validate-mandatory-rules/fixture-missing-cycle-commits/test.sh`
- [ ] `scripts/tests/validate-mandatory-rules/fixture-missing-envelope-status/test.sh`
- [ ] `scripts/tests/validate-mandatory-rules/fixture-missing-party-mode/test.sh`
- [ ] `scripts/tests/validate-mandatory-rules/fixture-pass-with-waiver/test.sh`
- [ ] `scripts/tests/validate-mandatory-rules/fixture-pass/test.sh`
- [ ] `scripts/tests/validate-mandatory-rules/run-all.sh`
- [ ] `scripts/tests/validator-mutation-proofs.sh`

## TIER 3 — `scripts/` top level naming an ai-dlc artifact (36 files)

Mixed. Apply the test individually — this tier is where domain code lives alongside machinery.

- [ ] `scripts/ai-dlc-reset-snapshot.sh`
- [ ] `scripts/audit-main-since.sh`
- [ ] `scripts/audit-rule-exercise.sh`
- [ ] `scripts/audit-stale-in-sprint-entries.sh`
- [ ] `scripts/chain_cache_retention_ecs.sh`
- [ ] `scripts/check-config-integrity-snapshot.sh`
- [ ] `scripts/check-exclusion-importers.sh`
- [ ] `scripts/check-rule-ref-reconcile.sh`
- [ ] `scripts/ci-local.sh`
- [ ] `scripts/compute-carryover-ratio.sh`
- [ ] `scripts/deploy-positionsnapshot-subgraph.sh`
- [ ] `scripts/generate-ancestry-proof.py`
- [ ] `scripts/generate-config-integrity-snapshot.sh`
- [ ] `scripts/generate-path-decision.py`
- [ ] `scripts/generate-sprint-status.py`
- [ ] `scripts/install-hooks.sh`
- [ ] `scripts/normalize-backlog-status.py`
- [ ] `scripts/query-closed-positions.sh`
- [ ] `scripts/query-position-snapshots.sh`
- [ ] `scripts/query-s3-cb-status.sh`
- [ ] `scripts/regen-boundary-fixtures.sh`
- [ ] `scripts/retro-replay-harness.sh`
- [ ] `scripts/run-pnl-reconciliation.py`
- [ ] `scripts/scan-stray-provenance.sh`
- [ ] `scripts/test-aws-smoke.sh`
- [ ] `scripts/test-subgraph-fee-accuracy.py`
- [ ] `scripts/test-validate-pr-scope.sh`
- [ ] `scripts/validate-il-revalidation.py`
- [ ] `scripts/validate-phase-sequencing.sh`
- [ ] `scripts/validate-provenance-invocations.sh`
- [ ] `scripts/validate-story-dev-record.sh`
- [ ] `scripts/validate-story-status-consistency.sh`
- [ ] `scripts/validate-subgraph-deploy.sh`
- [ ] `scripts/verify-forward-only-deploy.sh`
- [ ] `scripts/verify-s238-infra.sh`
- [ ] `scripts/wait-on-subgraph-synced.sh`

## LIKELY DOMAIN despite naming an ai-dlc artifact — deploy/infra shaped (10 files)

The operator named this class explicitly: *"scripts that are truly consumer owned and ai-dlc
agnostic do not belong there, for example the ecs deploy script."* Each of these deploys or
operates infrastructure and would keep its job with ai-dlc gone. **Default: STAYS.**

The worked example that proves the grammar over-captures: `scripts/ecs-deploy-subgraph.sh`
matches on ONE substring in ONE comment — `# Phase 0: ECS preset auto-switch for long-window
deploys (Sprint 141 retro Item I4)` — a provenance note, with ZERO ai-dlc-specific tokens.

- [ ] `scripts/chain_cache_retention_ecs.sh` — default STAYS
- [ ] `scripts/check-exclusion-importers.sh` — default STAYS
- [ ] `scripts/deploy-positionsnapshot-subgraph.sh` — default STAYS
- [ ] `scripts/query-s3-cb-status.sh` — default STAYS
- [ ] `scripts/test-aws-smoke.sh` — default STAYS
- [ ] `scripts/test-subgraph-fee-accuracy.py` — default STAYS
- [ ] `scripts/tests/test-s241-5-ac4-provenance-secret.sh` — default STAYS
- [ ] `scripts/validate-subgraph-deploy.sh` — default STAYS
- [ ] `scripts/verify-forward-only-deploy.sh` — default STAYS
- [ ] `scripts/wait-on-subgraph-synced.sh` — default STAYS

## The remainder (61 files)

- [ ] `docs/pre-ai-dlc/20260423-184725/_divergence/.claude/hooks/ai-dlc-continue.sh`
- [ ] `docs/pre-ai-dlc/20260423-184725/_divergence/.claude/hooks/ai-dlc-pause.sh`
- [ ] `docs/pre-ai-dlc/20260423-184725/_divergence/.claude/hooks/ai-dlc-protect.sh`
- [ ] `docs/pre-ai-dlc/20260425-130416/_divergence/.claude/hooks/ai-dlc-continue.sh`
- [ ] `docs/pre-ai-dlc/20260425-130416/_divergence/.claude/hooks/ai-dlc-pause.sh`
- [ ] `docs/pre-ai-dlc/20260425-130416/_divergence/.claude/hooks/ai-dlc-protect.sh`
- [ ] `docs/research/hook-swap-clustering-query.sh`
- [ ] `rebalancer/execlog_reason_classify.py`
- [ ] `rebalancer/reference_lib/pnl_oracle.py`
- [ ] `rebalancer/tests/test_s247_1_safeguard_runner.py`
- [ ] `rebalancer/tests/test_s250_1_telemetry_discriminator.py`
- [ ] `rebalancer/tests/test_s263_1_config_flip_default_sync.py`
- [ ] `scripts/ai-dlc/audit-rule-files.sh`
- [ ] `scripts/ai-dlc/core-paths.sh`
- [ ] `scripts/ai-dlc/sprint-status.sh`
- [ ] `scripts/ai-dlc/stamp-story-provenance.sh`
- [ ] `scripts/ai-dlc/sync-taught-schema.sh`
- [ ] `scripts/ai-dlc/validate-ac-falsifiability.sh`
- [ ] `scripts/ai-dlc/validate-adversarial-convergence.sh`
- [ ] `scripts/ai-dlc/validate-artifact-budget.sh`
- [ ] `scripts/ai-dlc/validate-audit-anchors.sh`
- [ ] `scripts/ai-dlc/validate-bmad-invocations.sh`
- [ ] `scripts/ai-dlc/validate-ci-gates.sh`
- [ ] `scripts/ai-dlc/validate-compact-window.sh`
- [ ] `scripts/ai-dlc/validate-cycle-commits.sh`
- [ ] `scripts/ai-dlc/validate-draft-stamps.sh`
- [ ] `scripts/ai-dlc/validate-escalation-resolution.sh`
- [ ] `scripts/ai-dlc/validate-escalation-status-vocabulary.sh`
- [ ] `scripts/ai-dlc/validate-fixture-drivability.sh`
- [ ] `scripts/ai-dlc/validate-gate-adjudication.sh`
- [ ] `scripts/ai-dlc/validate-gate-manifest.sh`
- [ ] `scripts/ai-dlc/validate-h2-attestation.sh`
- [ ] `scripts/ai-dlc/validate-layer-entries.sh`
- [ ] `scripts/ai-dlc/validate-locked-anchor.sh`
- [ ] `scripts/ai-dlc/validate-mandatory-rules.sh`
- [ ] `scripts/ai-dlc/validate-mutation-red.sh`
- [ ] `scripts/ai-dlc/validate-provenance-block.sh`
- [ ] `scripts/ai-dlc/validate-reattach-budget.sh`
- [ ] `scripts/ai-dlc/validate-retro-evidence.sh`
- [ ] `scripts/ai-dlc/validate-spawn-ledger.sh`
- [ ] `scripts/ai-dlc/validate-spec-adoption.sh`
- [ ] `scripts/ai-dlc/validate-spec-join.sh`
- [ ] `scripts/ai-dlc/validate-steering-budget.sh`
- [ ] `scripts/ai-dlc/validate-stub-audit.sh`
- [ ] `scripts/ai-dlc/verdict.sh`
- [ ] `scripts/ai-dlc/wait-for-deliverable.sh`
- [ ] `scripts/lib/gate-log-corpus.sh`
- [ ] `scripts/lib/gate-side-exclude.sh`
- [ ] `scripts/lib/meta-gate.sh`
- [ ] `scripts/lib/mtls.sh`
- [ ] `scripts/lib/pr-class.sh`
- [ ] `server/aggregator.py`
- [ ] `server/config_wallets.py`
- [ ] `server/test_aggregator_255_1_orientation.py`
- [ ] `server/test_aggregator_item_330.py`
- [ ] `server/test_aggregator_s256_2_gate.py`
- [ ] `server/tests/test_il_oracle_baseline.py`
- [ ] `server/tests/test_pool_pnl_lifetime_accumulator.py`
- [ ] `server/tests/test_s287_sr_f9_portfolio_handler_wiring.py`
- [ ] `tests/__meta__/test_substrate_audit_lce_string_constants.py`
- [ ] `tests/test_validate_cycle_commits_bypass.py`
