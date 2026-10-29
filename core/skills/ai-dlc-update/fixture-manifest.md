# Shipped-fixture manifest — SHARED, read-only data

The `core/fixtures/<name>/**` entries of the core-manifest list, one per fixture a consumer
receives (every `core/fixtures/*/` without a `.dist-only` marker). It is the second half of the
`core_manifest:` list in `reconcile/setup-sites.md`: a reader that wants the whole core file set
reads that block and this one, in that order, and gets exactly the set `core-manifest.md` lists.

**Why it is its own file, and why it sits OUTSIDE `reconcile/`.** This list gains a line for
every new shipping fixture. While it lived in `setup-sites.md`, that one-line append changed a
file inside `reconcile/`, and every fixture that declares the whole reconcile directory re-ran on
the consumer push carrying it, for a change no engine code treats differently. Here, inside the
skill but beside `reconcile/` rather than in it, the append dirties no reconcile-engine input.
It is still `ai-dlc-update`'s own file, so the skill's HARD CONSTRAINT (it reads only its own
files) holds.

**Readers.** `reconcile/preclassify.sh --untangle` (the manifest enumeration), and the
`setup-sites.md` fallback of `ai-dlc-core-guard.sh` and `core-paths.sh`. `apply.sh`'s
`manifest_dests` keeps only `scripts/ai-dlc/` destinations and does not need it.
`validate-enforcement-map.sh` I5 binds `setup-sites.md`'s block plus this one to
`core-manifest.md`, and holds the partition: fixture entries here, and nowhere else.

```yaml
core_manifest:
  - core/fixtures/agent-definition-render/**
  - core/fixtures/adversarial-citation/**
  - core/fixtures/apply-drift-after-write/**
  - core/fixtures/apply-drift-refile/**
  - core/fixtures/apply-legacy-script-path/**
  - core/fixtures/apply-restamp-theirs/**
  - core/fixtures/apply-restamp-worklist/**
  - core/fixtures/apply-restamp-worklist-b/**
  - core/fixtures/apply-restamp-worklist-c/**
  - core/fixtures/apply-setup-sited-merge/**
  - core/fixtures/apply-relabel-noop-row/**
  - core/fixtures/absorbed-specifics-survive/**
  - core/fixtures/answer-handoff-routing/**
  - core/fixtures/askuserquestion-citation/**
  - core/fixtures/command-args-citation/**
  - core/fixtures/operator-request-capture/**
  - core/fixtures/request-coverage/**
  - core/fixtures/scope-confirmation/**
  - core/fixtures/snapshot-archive-rotate/**
  - core/fixtures/snapshot-conservation/**
  - core/fixtures/snapshot-update-stamps/**
  - core/fixtures/held-stories/**
  - core/fixtures/trunk-audit-gate/**
  - core/fixtures/suppression-lifetime/**
  - core/fixtures/self-update-fixture-log/**
  - core/fixtures/snapshot-supersession-marker/**
  - core/fixtures/artifact-path-migration/**
  - core/fixtures/artifact-path-conformance/**
  - core/fixtures/artifact-section-heading-level/**
  - core/fixtures/span-of-containment/**
  - core/fixtures/setup-site-drift/**
  - core/fixtures/story-corpus-sprint-slot/**
  - core/fixtures/apply-worklist-rows/**
  - core/fixtures/apply-self-overwrite/**
  - core/fixtures/changelog-sprint-slot/**
  - core/fixtures/consolidation-residue/**
  - core/fixtures/apply-machinery-stamp/**
  - core/fixtures/layer-absorption-retire/**
  - core/fixtures/audit-anchors-schema/**
  - core/fixtures/blocker-adjudication-record/**
  - core/fixtures/bmad-invocation-resolve/**
  - core/fixtures/budget-summary-verdict/**
  - core/fixtures/check-15-bypass/**
  - core/fixtures/check-17-bypass/**
  - core/fixtures/check-17-counts/**
  - core/fixtures/check-1c-bypass/**
  - core/fixtures/check-23-draft-stamps/**
  - core/fixtures/check-24-adversarial-convergence/**
  - core/fixtures/check-24-adversarial-convergence-b/**
  - core/fixtures/check-24-adversarial-convergence-c/**
  - core/fixtures/check-24-adversarial-convergence-d/**
  - core/fixtures/check-25-steering-conduct/**
  - core/fixtures/check-31-ac-falsifiability/**
  - core/fixtures/check-3b-locked-anchor/**
  - core/fixtures/check-h1-recursion/**
  - core/fixtures/check-manifest-bypass/**
  - core/fixtures/check5-anchor-base/**
  - core/fixtures/check-22-spawn-ledger/**
  - core/fixtures/ci-gates-resolution/**
  - core/fixtures/consumer-suite-pool/**
  - core/fixtures/readset-skip/**
  - core/fixtures/readset-skip-b/**
  - core/fixtures/readset-skip-c/**
  - core/fixtures/readset-skip-d/**
  - core/fixtures/layer-qualifier-grain/**
  - core/fixtures/layer-conforms-to/**
  - core/fixtures/lib/**
  - core/fixtures/layer-entry-unreadable/**
  - core/fixtures/layer-extends-grain/**
  - core/fixtures/layer-retired-id-crosswalk/**
  - core/fixtures/layer-crosswalk-home/**
  - core/fixtures/layer-artifact-path-prescriptions/**
  - core/fixtures/layer-reference-resolution/**
  - core/fixtures/layer-adjudication-tier/**
  - core/fixtures/layer-title-join/**
  - core/fixtures/context-mode-protect/**
  - core/fixtures/context-provenance/**
  - core/fixtures/context-sensor/**
  - core/fixtures/core-paths-audit-diff/**
  - core/fixtures/core-script-boundary/**
  - core/fixtures/core-write-guard/**
  - core/fixtures/cycle-commits-enforce/**
  - core/fixtures/dispatch-model-guard/**
  - core/fixtures/divergence-hard-block/**
  - core/fixtures/escalation-citation/**
  - core/fixtures/extension-check-adoption/**
  - core/fixtures/escalation-status-vocabulary/**
  - core/fixtures/enforcement-map-yaml-plain/**
  - core/fixtures/process-rule-pins/**
  - core/fixtures/gate-adjudication/**
  - core/fixtures/gate-adjudication-rotate/**
  - core/fixtures/gate-remediation-deny/**
  - core/fixtures/gate-repair-record/**
  - core/fixtures/adversarial-shard-merge/**
  - core/fixtures/review-shard-merge/**
  - core/fixtures/remediator-shard-join/**
  - core/fixtures/content-seal/**
  - core/fixtures/document-partition/**
  - core/fixtures/subject-partition/**
  - core/fixtures/serial-remediation-worklist/**
  - core/fixtures/gate-series-rung/**
  - core/fixtures/gate-verdict-grep-shape/**
  - core/fixtures/h2-attest-scripts-dir/**
  - core/fixtures/handoff-completion-assertion/**
  - core/fixtures/handoff-record-carries-return/**
  - core/fixtures/handoff-resume-guard/**
  - core/fixtures/hook-registration-join/**
  - core/fixtures/implementation-join-yield/**
  - core/fixtures/escalation-delivery/**
  - core/fixtures/extract-push-flag-decision/**
  - core/fixtures/fold-architect-ledger-join/**
  - core/fixtures/foreground-budget-deny/**
  - core/fixtures/advisor-gate-deny/**
  - core/fixtures/update-preflight-push/**
  - core/fixtures/push-drain-refusals/**
  - core/fixtures/inflight-row-shape/**
  - core/fixtures/known-skills-extension/**
  - core/fixtures/layer-anchor-declaration/**
  - core/fixtures/layer-catalog-collision/**
  - core/fixtures/layer-debt-due-and-discharge/**
  - core/fixtures/layer-debt-ledger/**
  - core/fixtures/layer-readopt-gate/**
  - core/fixtures/ledger-reverify/**
  - core/fixtures/ledger-reverify-unfalsifiable/**
  - core/fixtures/ledger-reverify-dist-only-reach/**
  - core/fixtures/fixture-drivability/**
  - core/fixtures/ledger-rotate/**
  - core/fixtures/mandatory-rules-clean-tree/**
  - core/fixtures/mandatory-rules-skip-accounting/**
  - core/fixtures/mandatory-rules-snapshot-position/**
  - core/fixtures/mutation-red-replay/**
  - core/fixtures/carried-findings/**
  - core/fixtures/review-reroute/**
  - core/fixtures/trunk-audit-classes/**
  - core/fixtures/story-fields-derive/**
  - core/fixtures/transient-ignore-block/**
  - core/fixtures/trunk-push-bound/**
  - core/fixtures/file-mtime/**
  - core/fixtures/pause-hook-origin/**
  - core/fixtures/pause-question-in-prose/**
  - core/fixtures/postcompact-rulebook-recovery/**
  - core/fixtures/gate-resume/**
  - core/fixtures/fanout-payload-channel/**
  - core/fixtures/fanout-untracked-corpus/**
  - core/fixtures/preclassify-mode-bucket/**
  - core/fixtures/predicate-reclassification/**
  - core/fixtures/derivation-differential/**
  - core/fixtures/owed-derivations/**
  - core/fixtures/deploy-validate-smoke-classification/**
  - core/fixtures/story-evidence-scaffold/**
  - core/fixtures/review-carry-over-clauses/**
  - core/fixtures/provenance-flagless-default/**
  - core/fixtures/provenance-not-accessible/**
  - core/fixtures/reconcile-blocking-list/**
  - core/fixtures/reconcile-emit-report/**
  - core/fixtures/reconcile-emit-report-b/**
  - core/fixtures/reconcile-emit-report-c/**
  - core/fixtures/emit-report-refusal/**
  - core/fixtures/relabel-theirs-collision/**
  - core/fixtures/relocation-preclassify/**
  - core/fixtures/preclassify-rename-row/**
  - core/fixtures/requirements-step/**
  - core/fixtures/architecture-fast-track/**
  - core/fixtures/resume-whole-read/**
  - core/fixtures/retired-contract-token/**
  - core/fixtures/retired-layer-contract/**
  - core/fixtures/retired-layer-passage/**
  - core/fixtures/retired-layer-token/**
  - core/fixtures/retired-fixture-orphan/**
  - core/fixtures/consumer-machinery-inventory/**
  - core/fixtures/upstream-routing/**
  - core/fixtures/retro-audit-scans/**
  - core/fixtures/retro-branch-behind-main/**
  - core/fixtures/route-defect-classification/**
  - core/fixtures/self-update-gate/**
  - core/fixtures/self-update-gate-b/**
  - core/fixtures/self-update-gate-c/**
  - core/fixtures/self-update-gate-d/**
  - core/fixtures/self-update-reinvoke-liveness/**
  - core/fixtures/dist-clone/**
  - core/fixtures/setup-config-drift/**
  - core/fixtures/shadowed-local-validators/**
  - core/fixtures/snapshot-evidence-cell/**
  - core/fixtures/snapshot-section-schema/**
  - core/fixtures/spec-adoption-floor/**
  - core/fixtures/spec-join-integrity/**
  - core/fixtures/sprint-status-lifecycle/**
  - core/fixtures/story-provenance/**
  - core/fixtures/stray-party-mode-provenance/**
  - core/fixtures/subagent-probe/**
  - core/fixtures/taught-schema/**
  - core/fixtures/validate-mandatory-rules-revive/**
  - core/fixtures/validator-path-resolution/**
  - core/fixtures/verdict-pass-content/**
  - core/fixtures/wait-beat-liveness/**
  - core/fixtures/wait-stale-deliverable/**
  - core/fixtures/hermetic-runner/**
  - core/fixtures/whole-read-pool/**
  - core/fixtures/write-format-steering-multiformat/**
  - core/fixtures/updater-session-signals/**
  - core/fixtures/route-read-required/**
  - core/fixtures/artifact-derivations/**
  - core/fixtures/derivation-capture/**
  - core/fixtures/derivation-capture-worktree-root/**
  - core/fixtures/architecture-index-cell-escaping/**
  - core/fixtures/prepush-worktree-env-scrub/**
  - core/fixtures/retro-compliance-workflow/**
  - core/fixtures/post-write-gates/**
```
