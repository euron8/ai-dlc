# BL-583: value census of the push-suite families outside the 19 judged (batch 263)

Read-only census. No fixture was run, and none is removed in this release. The batch-263 paragraphs of BL-583
(`docs/backlog.md`) carry the summary figures.

## The standard (lead ruling, batch 263, ai-dlc-17)

Being the sole assertion of a property is not a catch on record. A family is KEEP only on one of two grounds:

- **KEEP-catch**: a recorded catch, meaning a gate red it raised that named a real defect.
- **KEEP-catch-SHARED**: one recorded catch that several families raised together. It is credited to the set, not
  to each family.
- **KEEP-consequence**: a named high-consequence verdict that it alone guards, judged on consequence, under
  `.claude/rules/operator-rulings.md` "A step with no measured value goes". Example: the only shipped assertion
  that a pull is DEFER rather than OK.

A family with neither is **NO-CATCH-ON-RECORD**. Deleting those families is a separate owed item in BL-583 and is
not done here.

A consequence counts as high only if a wrong verdict, with the family absent, would do one of the following:

1. Write wrong content to, or destroy content in, a consumer tree or a real repository: a pull or apply, a rotation,
   a migration, or a fixture writing into the caller's repo.
2. Classify a pull as OK, clean or applied when it must DEFER, block or refuse, or drop a HARD blocker from a pull
   report.
3. Let a shipped guard hook allow what it must deny.
4. Let a blocking gate pass on forged, unverified or unrun input, or skip the push suite on a changed tree.

Every family met the sole-assertion test, so its guarded verdict has no other assertion. Each family's property,
subject and coverage are kept in the sub-hands' records; the property is restated in the NO-CATCH rows. Detector,
pin, rendering, documentation and process-hook properties are NO-CATCH-ON-RECORD. A wrong answer there is a missed
warning or a wrong message, not one of the four.

## Columns

- **verdict**: KEEP-catch, KEEP-catch-SHARED, KEEP-consequence or NO-CATCH-ON-RECORD.
- **catch or consequence**: for KEEP-catch, the record of the catch. For KEEP-consequence, the one line saying what
  would go wrong if the family were absent. For NO-CATCH, the property it asserts.
- **red on record**: where a family has a red, its classification from the 22 `.git/ai-dlc-fixture-failures*`
  archives and the commit bodies is appended to the line. None of these 12 reds named a real shipped defect.
- **dispatch s**: loaded seconds. Each dispatched unit is priced at `.git/ai-dlc-fixture-durations` (main checkout,
  mtime 2026-11-21 07:07 local) and summed over the `done i/N <status> <unit>` lines of the 46 distinct push logs
  (md5-deduplicated) in the session scratchpads that print a `read-set keys: N of M fixture` line,
  2026-11-19T17:21Z to 2026-11-21T12:07Z.

## Method

The sole-assertion test came first. For each family, the subject and property were taken from the `run.sh` header
and the `!` lines of `inputs.decl`. Then one recursive `/usr/bin/grep` per subject basename was run over
`core/fixtures/*/run.sh`, `lib.sh` and `seed.sh`, and each namer's `ok`/`bad` lines were read for the same property
on the same kind of input.

Control: every subject grep hit the family's own files in the same invocation.

Seven read-only sub-hands ran it. Of the 216 families without a catch, 182 were the sole assertion and 34 were
partly covered, each with its uncovered part named. The consequence judgment above was then made by the census
author from each family's named property.

Limits:
- These verdicts rest on the header plus sampled assertion lines: `process-rule-pins`, `wait-beat-liveness`,
  `subagent-probe`, `context-sensor`, `divergence-hard-block`, `story-corpus-sprint-slot`,
  `sprint-status-lifecycle`, `check-17-bypass` and `shipped-rule-version-floor`.
- Part B of `ledger-reverify-dist-only-reach` was not searched in `procsub-staged-refusal`.
- `context-mode-protect` was searched on `ai-dlc-protect.sh` only.
- `layer-catalog-collision`, `relabel-theirs-collision` and `apply-relabel-noop-row` went red together on one
  subject bug (`CHANGELOG.md:27185`), so they are KEEP-catch-SHARED: one catch credited to the set (lead ruling,
  batch 263). Owed item 6 keeps at least one of the three, chosen by which arm still reds alone on that bug.

## Census

| family | verdict | catch or consequence | dispatch s |
|---|---|---|---:|
| `reconcile-emit-report` | KEEP-consequence | if absent: a pull report hand-edited to drop a HARD blocker, or with no rendered region, would pass --verify; red on record: FIXTURE-DEFECT (anchor): B1 literal grep at run.sh:2267 missed a respelled `--bucket-rows` hand-off in .20261120T183957Z.59501; 3467249ed restored the literal line (emit-report.sh:863/868) | 2012 |
| `procsub-staged-refusal` | KEEP-catch | 0.796.0: six silent-failure redirects (the record cites `.git/ai-dlc-fixture-failures.20261016T085900Z.80433`, no longer on disk) | 1766 |
| `reconcile-pull-driver` | KEEP-consequence | if absent: an ASK family decided without the operator would reach the consumer tree | 1675 |
| `derivation-differential` | NO-CATCH-ON-RECORD | no catch; property: clears the WORKLIST derivations row only for derivations this pull broke (reconcile/derivation-differential.sh) | 1610 |
| `layer-crosswalk-home` | NO-CATCH-ON-RECORD | no catch; property: W8 names a retired crosswalk row and its destination; undeclared crosswalk path refused (validate-layer-entries.sh) | 1572 |
| `layer-adjudication-tier` | KEEP-consequence | if absent: an ADJUDICATED layer clause would stop blocking without its digest-keyed record, or stay cleared after the entry changed | 1240 |
| `apply-setup-sited-merge` | KEEP-consequence | if absent: a consumer's setup values in a setup-sited file would be lost or a non-setup delta auto-resolved | 1176 |
| `emit-report-refusal` | KEEP-consequence | if absent: a detector that did not run would render as none, so the pull report would read clean over nothing | 1066 |
| `procsub-staged-refusal-boot` | KEEP-consequence | if absent: a failed producer in a bootstrapping reconcile script (ledger-reverify, preclassify, self-update-gate, unregistered-drift) would read as a clean verdict, so the pull would pass as OK | 1062 |
| `layer-contract-conformance` | NO-CATCH-ON-RECORD | no catch; property: I36-I65 silent on the shipping contract and each fires on its mutant (validate-enforcement-map.sh + layer-contract.yaml) | 984 |
| `layer-title-join` | NO-CATCH-ON-RECORD | no catch; property: absorption asked of prose headings only, with its two exclusions (reconcile/layer-drift.sh) | 980 |
| `apply-drift-after-write` | NO-CATCH-ON-RECORD | no catch; property: drift measured before phase 1 writes; a pure-apply file changed upstream is not consumer drift (reconcile/apply.sh); red on record: FIXTURE-DEFECT (anchor): same red and same fix as reconcile-emit-report (3467249ed, emit-report.sh:863); inferred from timing and fix | 770 |
| `ledger-reverify-unfalsifiable` | NO-CATCH-ON-RECORD | no catch; property: live theirs_lacks vs UNFALSIFIABLE by consumer reach; missing scan set refuses (reconcile/ledger-reverify.sh) | 732 |
| `retired-layer-token` | NO-CATCH-ON-RECORD | no catch; property: fires on a retired status word, quiet on 4 look-alike shapes (reconcile/retired-layer-token.sh) | 684 |
| `install-scaffold-ignored` | NO-CATCH-ON-RECORD | no catch; property: install reports every create-once scaffold path git ignores (install.sh, install-scaffold-ignore.sh) | 588 |
| `remediator-shard-join` | KEEP-consequence | if absent: two sharded remediators could write the same file and one repair would silently overwrite the other | 584 |
| `shipped-rule-version-floor` | NO-CATCH-ON-RECORD | no catch; property: below-2.0.64 report with valid JSON; silent with no rule (hooks/ai-dlc-rules-floor.sh, install.sh, uninstall.sh) | 561 |
| `apply-self-overwrite` | KEEP-consequence | if absent: apply.sh replacing itself, or a failed fetch, would leave an empty or broken core file on the consumer | 536 |
| `schema-install-fallback` | NO-CATCH-ON-RECORD | no catch; property: consumer-layout script finds its schema from the install (scripts/install.sh + schema-loading scripts) | 532 |
| `story-evidence-scaffold` | NO-CATCH-ON-RECORD | no catch; property: Strategy Test IDs table with a closed Kind vocabulary (validate-handoff-evidence.sh (Check 21), strategy-rows.sh, strategy-self-check.sh) | 496 |
| `gate-remediation-deny` | KEEP-catch | BL-181 (0.512.0): C-locale byte bug in `validate-suppression-lifetime.sh:252` (CHANGELOG 0.842.0 battery table) | 490 |
| `dispatch-model-guard` | NO-CATCH-ON-RECORD | no catch; property: injects the role's pinned tier through updatedInput.model (ai-dlc-dispatch-guard.sh) | 456 |
| `retired-contract-token` | NO-CATCH-ON-RECORD | no catch; property: a consumer reference to a retired contract is caught; re-pointed code and comments not flagged (reconcile/retired-tokens.sh) | 456 |
| `reconcile-blocking-list` | KEEP-consequence | if absent: a pull report that omits a HARD blocker would pass --check | 440 |
| `apply-legacy-script-path` | NO-CATCH-ON-RECORD | no catch; property: a pre-0.126.0 validator at the old path is moved and reported (reconcile/apply.sh) | 440 |
| `gate-resume` | NO-CATCH-ON-RECORD | no catch; property: an interrupted gate resumes the sliced plan minus settled checks (gate-slice.sh, gate-checkpoint.sh, ai-dlc-recover.sh) | 429 |
| `ledger-rotate` | KEEP-consequence | if absent: rotation would drop an OPEN entry or lose content | 396 |
| `vocabulary-index` | NO-CATCH-ON-RECORD | no catch; property: rendered index round-trips; each failure refuses with its own message (render-vocabulary-index.sh) | 390 |
| `layer-extends-grain` | NO-CATCH-ON-RECORD | no catch; property: no drift row outside the declared anchor, varying the commit span (validate-layer-entries.sh, layer-drift.sh) | 360 |
| `post-write-gates` | KEEP-consequence | if absent: a gate whose exit was never observed would read as passed instead of UNDECIDED | 356 |
| `dist-clone` | NO-CATCH-ON-RECORD | no catch; property: private main-only bare clone; CLI exit 0/1/2 (reconcile/dist-clone.sh) | 352 |
| `ledger-status-vocabulary` | NO-CATCH-ON-RECORD | no catch; property: I39 fails on a half-done status rename (validate-enforcement-map.sh I39) | 312 |
| `retro-compliance-workflow` | KEEP-consequence | if absent: the consumer's retro-compliance CI workflow would read green while skipping every step | 308 |
| `update-preflight-push` | NO-CATCH-ON-RECORD | no catch; property: the observable is declared prose in `ai-dlc-update/SKILL.md` (a pin, `run.sh:6-13`): AUTO-PUSH failure non-fatal, step 6 re-confirm, BL-986 R1-R4 | 301 |
| `layer-absorption-retire` | NO-CATCH-ON-RECORD | no catch; property: EXTENSION-RETIRE-CANDIDATE (LC-E6) fires, distinct from LC-E5 (reconcile/layer-drift.sh) | 300 |
| `layer-qualifier-grain` | NO-CATCH-ON-RECORD | no catch; property: anchor narrows drift varying the entry; qualifier authoring arms (validate-layer-entries.sh, layer-drift.sh) | 280 |
| `retired-layer-contract` | NO-CATCH-ON-RECORD | no catch; property: retired contract shape on a live override line flagged, quiet otherwise, never clean on nothing read (reconcile/retired-layer-contract.sh) | 280 |
| `self-update-fixture-log` | KEEP-consequence | if absent: the self-update push would be authorised without a matching recorded fixture verdict | 273 |
| `handoff-completion-assertion` | KEEP-consequence | if absent: an unpushed or dirty handoff would pass, and the work could be lost | 261 |
| `process-rule-pins` | NO-CATCH-ON-RECORD | no catch; property: three prose-only process rules pinned to their binding section (core/skills/ai-dlc prose) | 261 |
| `fixture-git-env-seam` | KEEP-consequence | if absent: a fixture run by hand under an inherited GIT_DIR would write into the caller's real repository; red on record: FIXTURE-DEFECT (J3): "98 *" measured 61 in .20261115T033707Z.33209; reset in 56877eb4d (0.1130.0) | 260 |
| `gate-adjudication` | KEEP-consequence | if absent: a gate with a missing escalated entry, blank evidence, absent verdict or stale nonce would pass instead of failing closed | 258 |
| `preclassify-rename-row` | KEEP-consequence | if absent: an upstream rename would be misclassified, leaving the old file or losing the new one on the consumer | 258 |
| `apply-machinery-stamp` | KEEP-consequence | if absent: the stamp would advance past machinery that was never applied, so the next pull would skip delivering it | 240 |
| `consumer-machinery-home` | NO-CATCH-ON-RECORD | no catch; property: I43/I44 fire on an undeclared or drifted ai-dlc-local home (validate-enforcement-map.sh I43, I44) | 240 |
| `postcompact-rulebook-recovery` | NO-CATCH-ON-RECORD | no catch; property: after compaction the lead is told to re-read the rulebook (ai-dlc-postcompact.sh, ai-dlc-recover.sh) | 231 |
| `setup-config-drift` | KEEP-consequence | if absent: a consumer edit outside a setup-config region would not be HARD, so the pull would overwrite it | 230 |
| `content-seal` | KEEP-consequence | if absent: bytes changed through a channel no hook sees would be accepted by the merge and join readers | 212 |
| `retired-layer-passage` | NO-CATCH-ON-RECORD | no catch; property: fires on a reproduced core line, quiet on a paraphrase (reconcile/retired-layer-passage.sh) | 210 |
| `gate-transition` | NO-CATCH-ON-RECORD | no catch; property: each gate's plan by value (core/scripts/gate-transition.sh) | 202 |
| `crosswalk-home-declaration` | NO-CATCH-ON-RECORD | no catch; property: I69 flags prose naming core-manifest.md as the crosswalk home (validate-enforcement-map.sh I69) | 200 |
| `ledger-reverify-dist-only-reach` | NO-CATCH-ON-RECORD | no catch; property: (A) a .dist-only-only naming commit is not consumer reach; (B) a failed staging write refuses (reconcile/ledger-reverify.sh) | 198 |
| `review-reroute` | NO-CATCH-ON-RECORD | no catch; property: --route misroute, Class grammar, --classes (partition-review-diff.sh, merge-review-shards.sh) | 190 |
| `self-update-reinvoke-liveness` | KEEP-consequence | if absent: a pull would be classified by the stale engine it is replacing, so the fix it delivers would not apply to its own pull | 189 |
| `divergence-hard-block` | KEEP-consequence | if absent: a DIVERGENT_HARD_BLOCK or stall would not stop the cycle | 186 |
| `relocation-preclassify` | KEEP-consequence | if absent: a consumer's locally edited legacy validator would be treated as identical and moved or replaced | 180 |
| `apply-relabel-noop-row` | KEEP-catch-SHARED | same subject bug as layer-catalog-collision (CHANGELOG.md:27185) | 175 |
| `taught-schema` | NO-CATCH-ON-RECORD | no catch; property: taught and read provenance schemas are one (validate-provenance-block.sh, sync-taught-schema.sh) | 165 |
| `check-22-spawn-ledger` | NO-CATCH-ON-RECORD | no catch; property: tier mismatch, unreadable role file, missing citation, PRE-LEDGER exit 3 (validate-spawn-ledger.sh (Check 22)) | 156 |
| `blocker-adjudication-record` | NO-CATCH-ON-RECORD | no catch; property: SKILL.md cite-the-command and inference-label pins (ai-dlc-update SKILL.md + reconcile/pull.sh) | 154 |
| `fold-architect-ledger-join` | NO-CATCH-ON-RECORD | no catch; property: a folded fix story must show an architect dispatch (Check 17) (validate-spawn-ledger.sh --fold-architect) | 152 |
| `bmad-invocation-resolve` | NO-CATCH-ON-RECORD | no catch; property: dangling and dead-shim invocations FAIL (validate-bmad-invocations.sh) | 143 |
| `story-evidence-receipts` | NO-CATCH-ON-RECORD | no catch; property: BL-809/815/843 receipts and the C3 run set (validate-handoff-evidence.sh) | 120 |
| `h2-attest-scripts-dir` | NO-CATCH-ON-RECORD | no catch; property: consumer-layout --attest prints the H2_ATTESTED v1 line (validate-h2-attestation.sh); red on record: FIXTURE-DEFECT (J3): "116 *" measured 115 in .20261115T033707Z.33209; reset in 56877eb4d | 120 |
| `apply-worklist-rows` | NO-CATCH-ON-RECORD | no catch; property: every WORKLIST/DECISION row prints its detail; ATOMIC emits its last step (reconcile/apply.sh) | 112 |
| `requirements-step` | NO-CATCH-ON-RECORD | no catch; property: the requirements step replaced discovery + research-requirements in carry-over and feature rows (steps/requirements.md and its joins) | 103 |
| `wait-beat-liveness` | NO-CATCH-ON-RECORD | no catch; property: the join tells a slow teammate from an idle one (wait-for-deliverable.sh) | 97 |
| `handoff-record-carries-return` | KEEP-catch | real red in `.git/ai-dlc-fixture-failures.20261112T135904Z.54396` (b256 analysis) | 94 |
| `snapshot-update-stamps` | NO-CATCH-ON-RECORD | no catch; property: writes a valid update; writes nothing when the stamp check refuses (snapshot-update.sh) | 84 |
| `changelog-sprint-slot` | NO-CATCH-ON-RECORD | no catch; property: every changelog prescription names the sprint slot (core step docs / SKILL.md) | 84 |
| `core-write-guard` | KEEP-consequence | if absent: an edit to a core step file would be allowed instead of routed to overrides/extensions | 78 |
| `gate-verdict-grep-shape` | NO-CATCH-ON-RECORD | no catch; property: the mandated verdict grep matches the template's shape (check-sprint-review-verdicts.sh vs code-reviewer.md template) | 72 |
| `path-mapping-render` | NO-CATCH-ON-RECORD | no catch; property: renders the path-mapping region; --check fails on drift (scripts/render-path-mapping.sh) | 72 |
| `escalation-status-vocabulary` | NO-CATCH-ON-RECORD | no catch; property: fires on an off-vocabulary status; vocabulary derived (validate-escalation-status-vocabulary.sh) | 70 |
| `extract-push-flag-decision` | NO-CATCH-ON-RECORD | no catch; property: extract decides push_candidate on the domain-local bullet (reconcile/untangle.md step 7u) | 70 |
| `updater-session-signals` | NO-CATCH-ON-RECORD | no catch; property: Rule 29 pause exempts the updater, typed or Skill-invoked, and nothing else (ai-dlc-acknowledge.sh, ai-dlc-dispatch-guard.sh) | 69 |
| `standing-rulings-hook` | NO-CATCH-ON-RECORD | no catch; property: the AskUserQuestion PreToolUse hook and grammar mode (core/hooks/ai-dlc-standing-rulings.sh) | 57 |
| `architecture-fast-track` | NO-CATCH-ON-RECORD | no catch; property: the no-impact fast-track predicate is extracted, executed and byte-joined (steps/architecture.md) | 56 |
| `absorbed-specifics-survive` | NO-CATCH-ON-RECORD | no catch; property: text absorbed from consumers' deleted copies is present in core (core/skills/ai-dlc/SKILL.md) | 56 |
| `settings-merge-documented-form` | NO-CATCH-ON-RECORD | no catch; property: the documented settings-merge invocations run (SKILL.md + settings-merge.sh) | 56 |
| `transient-ignore-block` | KEEP-consequence | if absent: the renderer would rewrite consumer .gitignore content outside its marked region | 55 |
| `held-stories` | NO-CATCH-ON-RECORD | no catch; property: unheld ready-for-dev stories not in flight are caught (validate-held-stories.sh) | 54 |
| `budget-summary-verdict` | NO-CATCH-ON-RECORD | no catch; property: the summary line follows what the run printed, not its exit code (validate-artifact-budget.sh) | 52 |
| `handoff-resume-guard` | NO-CATCH-ON-RECORD | no catch; property: blocks a missed resume prompt, passes the four-hyphen one (ai-dlc-continue.sh Check 0) | 46 |
| `extension-check-adoption` | NO-CATCH-ON-RECORD | no catch; property: dry-run names exactly the unanchored ids (reconcile/adopt-extension-checks.sh) | 45 |
| `write-format-steering-multiformat` | NO-CATCH-ON-RECORD | no catch; property: several declared formats each bound to the right string and file (validate-write-format-steering.sh) | 42 |
| `deploy-validate-smoke-classification` | NO-CATCH-ON-RECORD | no catch; property: smoke_run_evidence fields and transient-failure definition pinned (deploy-validate.md section 3) | 42 |
| `context-provenance` | NO-CATCH-ON-RECORD | no catch; property: marker at byte 0, nonce store membership, JSON validity (hooks/ai-dlc-context-provenance.sh) | 39 |
| `consumer-machinery-inventory` | NO-CATCH-ON-RECORD | no catch; property: LC-M1/E18 and LC-M2/W10 fire only for machinery outside the declared home (validate-layer-entries.sh); red on record: FIXTURE-DEFECT (J3): "53 *" measured 14 in .20261115T160038Z.37066; set in d619fe62a (0.1135.0) | 36 |
| `setup-site-drift` | NO-CATCH-ON-RECORD | no catch; property: a setup-sited core file equals theirs outside its spans; non-zero scanned count (reconcile/setup-site-drift.sh) | 33 |
| `carried-findings` | NO-CATCH-ON-RECORD | no catch; property: re-review fails on an unanswered prior finding, passes the near-miss (validate-carried-findings.sh) | 33 |
| `implementation-join-yield` | NO-CATCH-ON-RECORD | no catch; property: a live wait-beat lets the lead yield; a stall is still blocked (ai-dlc-continue.sh (Stop hook)) | 32 |
| `check-17-counts` | NO-CATCH-ON-RECORD | no catch; property: every evaluation block incl. verdict-less sub-skills carries findings_* counts (validate-provenance-block.sh) | 28 |
| `artifact-section-heading-level` | NO-CATCH-ON-RECORD | no catch; property: an artifact-section heading is a sibling of the numbered step (reconcile/lib.sh with steps/retro.md) | 28 |
| `resume-whole-read` | NO-CATCH-ON-RECORD | no catch; property: resume whole-reads the snapshot behind a budget check (steps/route.md, handoff.md) | 26 |
| `upstream-routing` | NO-CATCH-ON-RECORD | no catch; property: misrouted carry-over entry told from a routed one; reading nothing exits 2 (audit-upstream-routing.sh) | 25 |
| `artifact-path-conformance` | NO-CATCH-ON-RECORD | no catch; property: blocks exactly the migration move set, reports undeclared areas (validate-artifact-paths.sh) | 22 |
| `check-31-ac-falsifiability` | NO-CATCH-ON-RECORD | no catch; property: forbidden term on header or continuation FAILs; dangling prior_evidence FAILs (validate-ac-falsifiability.sh (Check 31)) | 22 |
| `pause-hook-origin` | NO-CATCH-ON-RECORD | no catch; property: pause flag raised only for operator prose; PAUSE_SKIPPED logged (ai-dlc-pause.sh) | 22 |
| `finding-grammar-binding` | NO-CATCH-ON-RECORD | no catch; property: the three finding-grammar copies are byte-identical (parse_shard, src_ids, j3_keys) | 20 |
| `settings-merge-unparseable-template` | NO-CATCH-ON-RECORD | no catch; property: refuses a 0-byte, non-JSON or wrong-shape template (reconcile/settings-merge.sh --check) | 18 |
| `hook-registration-join` | KEEP-consequence | if absent: a hook on disk that was never registered (for example the core guard) would pass as installed and never fire | 18 |
| `review-carry-over-clauses` | NO-CATCH-ON-RECORD | no catch; property: the deferral duty and un-exercised-branch clauses sit where pinned (steps/sprint-review.md section 3, dev.md item 15) | 14 |
| `pause-question-in-prose` | NO-CATCH-ON-RECORD | no catch; property: a pause question sent as prose is noticed both sides of the pause flag (ai-dlc-continue.sh, ai-dlc-handoff-pending.sh) | 12 |
| `fanout-payload-channel` | NO-CATCH-ON-RECORD | no catch; property: payloads travel by file, never the child's environment (report-propagation-fanout.sh) | 12 |
| `check-15-bypass` | KEEP-consequence | if absent: an adversarial stub-audit bypass variant would pass the gate check | 9 |
| `fanout-untracked-corpus` | NO-CATCH-ON-RECORD | no catch; property: gitignored excluded, header count, tracked still scanned, exit 3 (report-propagation-fanout.sh) | 9 |
| `layer-reference-resolution` | NO-CATCH-ON-RECORD | no catch; property: W7, W9 and the E15 remedy form (validate-layer-entries.sh) | 0 |
| `artifact-derivations` | NO-CATCH-ON-RECORD | no catch; property: true/stale differential; message names recorded and actual value (validate-artifact-derivations.sh) | 0 |
| `hermetic-runner` | KEEP-consequence | if absent: an undeclared read would go unseen, so the read-set skip would pass a fixture whose input moved; red on record: BATTERY: "mutant hook (identity map) was not caught" in .20261114T032701Z.28710; anchor reworded in 4c3a82362; batteries deleted in 56877eb4d | 0 |
| `artifact-path-migration` | KEEP-consequence | if absent: the migration would move a consumer artifact it cannot derive instead of refusing | 0 |
| `consumer-suite-pool` | KEEP-consequence | if absent: the consumer suite could pass having run no fixture | 0 |
| `subject-partition` | NO-CATCH-ON-RECORD | no catch; property: SPEC plus prd from the recorded base; refusals on 0/2 SPECs, no changes, wrong sha (partition-subject.sh) | 0 |
| `adversarial-citation` | NO-CATCH-ON-RECORD | no catch; property: operator-citation gate: vacuous pass, fail, pass when fixed (validate-adversarial-convergence.sh F6) | 0 |
| `validator-fork-budget` | KEEP-catch | I93 widening put the tree 42 over `FORK_BUDGET` (CHANGELOG.md:33616) | 0 |
| `census-hermetic-coverage` | NO-CATCH-ON-RECORD | no catch; property: hidden undeclared input scores MISMATCH PLAIN-MORE (scripts/census-hermetic-coverage.sh) | 0 |
| `smoke-surface-ignored` | NO-CATCH-ON-RECORD | no catch; property: WARN before SKIP, exit unchanged (validate-handoff-evidence.sh SMOKE-SURFACE-IGNORED) | 0 |
| `fixture-inprocess` | NO-CATCH-ON-RECORD | no catch; property: the static in-process validator refuses or credits seeded probes (scripts/validate-fixture-inprocess.sh) | 0 |
| `validator-path-resolution` | KEEP-catch | two validators counting `..` from their install path (commit 79a7d27e6) | 0 |
| `prepush-pool-depth` | KEEP-consequence | if absent: nested hook pools would fan out without bound (the fork-bomb shape); red on record: FIXTURE-DEFECT: two settle-bound harness reds (BL-985, docs/backlog.archive.md:41956-41968, fixed in the fixture in e3cb7710f) and one J3 socket-stdin red (BL-1050, 73de94459) | 0 |
| `whole-read-pool` | NO-CATCH-ON-RECORD | no catch; property: the budget comes from the reader's resolved window (validate-artifact-budget.sh, ai-dlc-window.sh) | 0 |
| `gate-adjudication-rotate` | KEEP-consequence | if absent: a closed sprint's verdicts could be lost or half-written by rotation, and the remediation guard could stay ALLOW | 0 |
| `layer-entry-unreadable` | NO-CATCH-ON-RECORD | no catch; property: "could not read entry" distinct from "no such key" (validate-layer-entries.sh) | 0 |
| `preclassify-mode-bucket` | KEEP-consequence | if absent: a mode-only upstream change can leave a shipped guard hook non-executable on a consumer still at 644, so the hook never fires (`run.sh:9-24`, arm A `:371-375`; `apply.sh:2005` no-ops ALREADY-AT-THEIRS, so `sync_mode_from_theirs` (`:761`) never runs; `templates/settings.json.template` registers hooks by bare path, e.g. `:127`) | 0 |
| `spec-join-integrity` | NO-CATCH-ON-RECORD | no catch; property: each of 3 joins FAILs on its offender, DISARMs, PASSes healthy (validate-spec-join.sh) | 0 |
| `layer-artifact-path-prescriptions` | NO-CATCH-ON-RECORD | no catch; property: a layer-prescribed artifact path is held to the grammar (validate-layer-entries.sh LC-R4/W11) | 0 |
| `retro-audit-scans` | NO-CATCH-ON-RECORD | no catch; property: retro Step 4 scans can fail and refuse vacuous passes (audit-rule-files.sh, validate-gate-manifest.sh) | 0 |
| `advisor-gate-deny` | NO-CATCH-ON-RECORD | no catch; property: deny and allow verdicts on synthesized PreToolUse JSON (ai-dlc-advisor-gate.sh) | 0 |
| `derivation-capture` | NO-CATCH-ON-RECORD | no catch; property: a derived block is witnessed when written (hooks/ai-dlc-derivation-capture.sh) | 0 |
| `escalation-citation` | NO-CATCH-ON-RECORD | no catch; property: Check 2 three-step proof and legacy scoping guards (validate-escalation-resolution.sh) | 0 |
| `wait-stale-deliverable` | NO-CATCH-ON-RECORD | no catch; property: a pre-join file is not DELIVERED; the beat still arms (wait-for-deliverable.sh) | 0 |
| `stray-party-mode-provenance` | NO-CATCH-ON-RECORD | no catch; property: a stray party-mode block anywhere in the corpus is caught (validate-provenance-block.sh) | 0 |
| `context-sensor` | NO-CATCH-ON-RECORD | no catch; property: Stop-hook sensor output and fire state (ai-dlc-context-sensor.sh) | 0 |
| `foreground-budget-deny` | NO-CATCH-ON-RECORD | no catch; property: denies a foreground Bash call over budget; allow twins (ai-dlc-foreground-budget.sh) | 0 |
| `backlog-real-ledger` | NO-CATCH-ON-RECORD | no catch; property: j1 and b16 joins on a real-size ledger snapshot (validate-backlog-receipts.sh, validate-backlog-size.sh); red on record: FIXTURE-DEFECT (decl): three "absent from this sandbox; add it to inputs.decl" reds, fixed by decl rows (7541acf55 inferred, a3ec19ebf, 4c3a82362) | 0 |
| `backlog-receipt-traced-removal` | NO-CATCH-ON-RECORD | no catch; property: M1, R13 traced removal with controls and ceiling, M3 (validate-backlog-receipts.sh); red on record: FIXTURE-DEFECT (J3): count drift in .20261115T033707Z.33209 and .20261115T160038Z.37066 | 0 |
| `suppression-lifetime` | KEEP-consequence | if absent: an expired or terminal suppression would close a still-red check for good | 0 |
| `agent-definition-render` | NO-CATCH-ON-RECORD | no catch; property: projects roles into .claude/agents; --check drift; foreign definitions left alone (render-agent-definitions.sh) | 0 |
| `layer-conforms-to` | NO-CATCH-ON-RECORD | no catch; property: conforms_to receipt and LAYER_CONFORMANCE footer can fail (validate-layer-entries.sh) | 0 |
| `mutation-red-replay` | NO-CATCH-ON-RECORD | no catch; property: grades a claim only when it actually mutated (validate-mutation-red.sh) | 0 |
| `scope-confirmation` | NO-CATCH-ON-RECORD | no catch; property: an operator-seen scope told from one claiming to be seen (validate-scope-confirmation.sh (Check 34)) | 0 |
| `layer-retired-id-crosswalk` | NO-CATCH-ON-RECORD | no catch; property: moved id silent, shallow-clone refusal, zero-entry and migrated consumers exit 0 (validate-layer-entries.sh E16) | 0 |
| `plan-shape` | KEEP-catch | v0.293.0 regression in `scripts/validate-plan-shape.sh` (CHANGELOG.md:41842) | 0 |
| `sprint-status-lifecycle` | NO-CATCH-ON-RECORD | no catch; property: sprint_id derived over canonical states; freeze+roll atomic and idempotent (sprint-status.sh) | 0 |
| `core-paths-audit-diff` | KEEP-consequence | if absent: an in-place consumer edit of a core file (including a mode-only change) would pass the immutability audit and be overwritten by the next pull | 0 |
| `layer-catalog-collision` | KEEP-catch-SHARED | one catch credited to the set of three, not to each: `relabel-extension-checks.sh` sed delimiter, red against a green origin/main control (CHANGELOG.md:27185) | 0 |
| `check-25-steering-conduct` | NO-CATCH-ON-RECORD | no catch; property: exact violation integer; backgrounded call counts 0 (validate-steering-budget.sh --count) | 0 |
| `document-partition` | KEEP-consequence | if absent: the assembler would write sections back and corrupt the document | 0 |
| `mandatory-rules-snapshot-position` | NO-CATCH-ON-RECORD | no catch; property: deploy-validate after retro FAILs; retro and terminal spellings PASS (validate-mandatory-rules.sh Check 8) | 0 |
| `story-provenance` | NO-CATCH-ON-RECORD | no catch; property: --check drift; idempotent; refuses placeholder id and unconverged cycle (stamp-story-provenance.sh) | 0 |
| `suite-dispatch-order` | NO-CATCH-ON-RECORD | no catch; property: longest-first from the durations record; glob-order fallback (pre-push pool) | 0 |
| `fixture-invocation-budget` | NO-CATCH-ON-RECORD | no catch; property: end-to-end invocation budget, armed and unarmed (validate-fixture-invocations.sh via hermetic-run.sh) | 0 |
| `inflight-row-hook` | NO-CATCH-ON-RECORD | no catch; property: writes, flips or leaves the exact In-Flight row (ai-dlc-inflight-row.sh) | 0 |
| `snapshot-evidence-cell` | NO-CATCH-ON-RECORD | no catch; property: Check 15 refuses a Check 14 row written without running the budget check (validate-artifact-budget.sh, check-owed-derivations.sh) | 0 |
| `subagent-probe` | NO-CATCH-ON-RECORD | no catch; property: the SubagentStop probe writes its row; none with no snapshot (ai-dlc-subagent-probe.sh) | 0 |
| `derivation-capture-worktree-root` | NO-CATCH-ON-RECORD | no catch; property: a linked-worktree block is judged against the worktree's files (ai-dlc-derivation-capture.sh) | 0 |
| `inflight-row-shape` | NO-CATCH-ON-RECORD | no catch; property: In-Flight rows only, never struck rows; offender named (validate-artifact-budget.sh) | 0 |
| `layer-anchor-declaration` | NO-CATCH-ON-RECORD | no catch; property: E7, E8, E9, E3 widening (validate-layer-entries.sh) | 0 |
| `predicate-reclassification` | NO-CATCH-ON-RECORD | no catch; property: reports which stored series a predicate change flips (reconcile/predicate-differential.sh) | 0 |
| `askuserquestion-citation` | NO-CATCH-ON-RECORD | no catch; property: --cite accepts an AskUserQuestion answer, only the answer (validate-steering-budget.sh --cite) | 0 |
| `snapshot-section-schema` | NO-CATCH-ON-RECORD | no catch; property: an eighth snapshot section is refused and named (validate-artifact-budget.sh) | 0 |
| `context-mode-protect` | KEEP-consequence | if absent: protected files would reach context-mode | 0 |
| `check5-anchor-base` | NO-CATCH-ON-RECORD | no catch; property: Check 5 fires and FAILs from the prior-sprint anchor; resolver retirement (validate-mandatory-rules.sh Check 5) | 0 |
| `prepush-worktree-env-scrub` | KEEP-consequence | if absent: fixtures dispatched from a linked-worktree push would run with the caller's GIT_DIR and touch the real repository; red on record: FIXTURE-DEFECT (world): BL-1048 receipt world red in .20261114T032701Z.28710; 4c3a82362 made the hook ratchet step SKIP where its guard is absent so fixture worlds stay green (the record frames it as fixture-world accommodation; borderline) | 0 |
| `trunk-audit-gate` | NO-CATCH-ON-RECORD | no catch; property: Check 36 maps each trunk-audit exit to its verdict (validate-trunk-audit-gate.sh) | 0 |
| `gate-series-rung` | NO-CATCH-ON-RECORD | no catch; property: series_stall_run / boundary / nonce arms and legacy posture fire (validate-gate-adjudication.sh --series) | 0 |
| `mandatory-rules-skip-accounting` | NO-CATCH-ON-RECORD | no catch; property: checks 2/4/5 skips name themselves; multi-skip floor; zero-skip headline (validate-mandatory-rules.sh) | 0 |
| `snapshot-supersession-marker` | NO-CATCH-ON-RECORD | no catch; property: marker shapes for superseded content rejected (validate-artifact-budget.sh) | 0 |
| `provenance-flagless-default` | NO-CATCH-ON-RECORD | no catch; property: --allow-missing acquits one rung only; env var does not; conflicting flags usage error (validate-provenance-block.sh) | 0 |
| `check-17-bypass` | KEEP-consequence | if absent: forged provenance blocks (the sprint-v* forgery matrix) would pass Check 17 | 0 |
| `request-coverage` | NO-CATCH-ON-RECORD | no catch; property: dropped topic fails; previous sprint's block and incidental mentions do not cover (validate-request-coverage.sh) | 0 |
| `push-drain-refusals` | NO-CATCH-ON-RECORD | no catch; property: a refused digest is PUSH-REFUSED, otherwise PUSH-CANDIDATE (reconcile/push-drain.sh) | 0 |
| `release-version-triple` | NO-CATCH-ON-RECORD | no catch; property: subject, VERSION, CHANGELOG heading agree (scripts/validate-release-version.sh) | 0 |
| `serial-remediation-worklist` | NO-CATCH-ON-RECORD | no catch; property: worklist derived from bytes the splits keep; each half can fail (serial-remediation-worklist.sh) | 0 |
| `audit-anchors-schema` | NO-CATCH-ON-RECORD | no catch; property: header rendered from schema; --check drift; fails closed on unreadable schema (validate-audit-anchors.sh) | 0 |
| `check-3b-locked-anchor` | NO-CATCH-ON-RECORD | no catch; property: mis-anchor, uncheckable, requires-context, dangling, nothing-verified (validate-locked-anchor.sh) | 0 |
| `command-args-citation` | NO-CATCH-ON-RECORD | no catch; property: accepts slash-command arguments and only those (validate-steering-budget.sh --cite) | 0 |
| `cycle-commits-enforce` | NO-CATCH-ON-RECORD | no catch; property: 3-cycle floor fails at 2; all-exempt is NOTHING MEASURED (validate-cycle-commits.sh via Check 2) | 0 |
| `answer-handoff-routing` | NO-CATCH-ON-RECORD | no catch; property: a handoff arriving as an AskUserQuestion answer is routed (ai-dlc-answer-capture.sh) | 0 |
| `backlog-ledger` | KEEP-consequence | if absent: backlog rotation would archive a live entry | 0 |
| `snapshot-conservation` | KEEP-consequence | if absent: destroyed snapshot content would pass Check 35 as moved | 0 |
| `claude-rules-joins` | NO-CATCH-ON-RECORD | no catch; property: CLAUDE.md to .claude/rules join (scripts/validate-claude-rules.sh) | 0 |
| `layer-debt-due-and-discharge` | NO-CATCH-ON-RECORD | no catch; property: closes_owed discharge rows not filed as undeclared; near-miss and empty boundary (audit-layer-debt.sh) | 0 |
| `layer-debt-ledger` | NO-CATCH-ON-RECORD | no catch; property: undischarged debt reported OPEN; missing register DISARMED exit 2 (audit-layer-debt.sh) | 0 |
| `resolve-cited-paths` | NO-CATCH-ON-RECORD | no catch; property: every cited path resolves against tracked files (resolve-cited-paths.sh) | 0 |
| `route-read-required` | NO-CATCH-ON-RECORD | no catch; property: a session that never read route.md cannot produce files (ai-dlc-acknowledge.sh) | 0 |
| `check-23-draft-stamps` | NO-CATCH-ON-RECORD | no catch; property: unstamped drafts FAIL, stamped pass (validate-draft-stamps.sh) | 0 |
| `provenance-not-accessible` | NO-CATCH-ON-RECORD | no catch; property: NOT_ACCESSIBLE accepted; fabricated id or placeholder FAIL (validate-provenance-block.sh) | 0 |
| `suite-content-key` | KEEP-consequence | if absent: a wrong whole-suite key would skip the push suite on a changed tree | 0 |
| `trunk-push-bound` | NO-CATCH-ON-RECORD | no catch; property: the licensed trunk commit passes only with that subject and path (validate-audit-anchors.sh) | 0 |
| `verdict-pass-content` | NO-CATCH-ON-RECORD | no catch; property: the PASS line carries evidence of a run (verdict.sh) | 0 |
| `known-skills-extension` | NO-CATCH-ON-RECORD | no catch; property: bare-array form; malformed fails closed; missing counts as absent (validate-provenance-block.sh) | 0 |
| `shadowed-local-validators` | NO-CATCH-ON-RECORD | no catch; property: no fork, no shadow, orphan, subdirectory, close-grammar cases (reconcile/warn-shadowed-local-validators.sh); red on record: BATTERY: 867597ab9 changes only core/fixtures files and rebuilds the fixture's mutants; batteries deleted in 56877eb4d | 0 |
| `spec-adoption-floor` | NO-CATCH-ON-RECORD | no catch; property: no declaration gives exit 2 PENDING, never 0 (validate-spec-adoption.sh) | 0 |
| `architecture-index-cell-escaping` | NO-CATCH-ON-RECORD | no catch; property: free text escaped into table cells (gen-architecture-index.js) | 0 |
| `core-script-boundary` | KEEP-consequence | if absent: an edit to a shipped validator under scripts/ai-dlc/ or a core template would be allowed | 0 |
| `escalation-delivery` | NO-CATCH-ON-RECORD | no catch; property: a SendMessage saying it failed leaves an event line (ai-dlc-escalation-delivery.sh) | 0 |
| `file-mtime` | NO-CATCH-ON-RECORD | no catch; property: mtime as epoch plus ISO UTC (file-mtime.sh) | 0 |
| `relabel-theirs-collision` | KEEP-catch-SHARED | same subject bug as layer-catalog-collision (CHANGELOG.md:27185) | 0 |
| `trunk-audit-classes` | NO-CATCH-ON-RECORD | no catch; property: flags a commit whose class validator fails on its own tree (validate-cycle-commits.sh --audit-trunk) | 0 |
| `validate-mandatory-rules-revive` | NO-CATCH-ON-RECORD | no catch; property: Checks 4/5 skip; Check 3 envelope; CLI and in-process agree (validate-mandatory-rules.sh) | 0 |
| `enforcement-map-yaml-plain` | NO-CATCH-ON-RECORD | no catch; property: no plain value carries a mapping indicator (enforcement-map.yaml) | 0 |
| `route-defect-classification` | NO-CATCH-ON-RECORD | no catch; property: four distinct valid snapshots carrying the adjudicator's fields (its seed.sh (Check 27 corpus)) | 0 |
| `span-of-containment` | NO-CATCH-ON-RECORD | no catch; property: span ends at same-or-higher heading; containment match (reconcile/lib.sh span_of) | 0 |
| `backlog-size-ceiling` | NO-CATCH-ON-RECORD | no catch; property: entry-denominated ceiling probes (scripts/validate-backlog-size.sh) | 0 |
| `consolidation-residue` | NO-CATCH-ON-RECORD | no catch; property: working-file paths carry the sprint slot; disposition named (steps/artifact-consolidation.md) | 0 |
| `backlog-rotate-fence-guard` | KEEP-consequence | if absent: a ledger with a fenced entry-shaped line would be rotated, archiving or losing entries | 0 |
| `plan-rotate` | KEEP-consequence | if absent: plan rotation could archive a LIVE section or lose lines from docs/plans (same class as `ledger-rotate` and `backlog-rotate-fence-guard`; `run.sh:1-5` header: keeps every section its declaration block names LIVE, refuses rather than guessing on a cut) | 0 |
| `retired-fixture-orphan` | NO-CATCH-ON-RECORD | no catch; property: a .dist-only fixture the consumer carries is reported; consumer-owned ones are not; exit 0 (reconcile/retired-fixtures.sh) | 0 |
| `pregate-self-check` | NO-CATCH-ON-RECORD | no catch; property: steps derived from the hook prefix; each guard fires (scripts/pregate-self-check.sh) | 0 |
| `seed-verdict-store-red-print` | NO-CATCH-ON-RECORD | no catch; property: a red seed prints the J3 row above >5 trailing lines (scripts/seed-verdict-store.sh) | 0 |
| `snapshot-edit-deny` | KEEP-consequence | if absent: an edit of the pipeline snapshot by an edit tool would be allowed | 0 |
| `story-corpus-sprint-slot` | NO-CATCH-ON-RECORD | no catch; property: empty corpus SKIP, misplaced FAIL, slot PASS (sprint-status.sh and corpus readers) | 0 |
| `gate-repair-record` | NO-CATCH-ON-RECORD | no catch; property: repair-record arm, delegated vs inline (validate-gate-adjudication.sh) | 0 |
| `ci-gates-resolution` | NO-CATCH-ON-RECORD | no catch; property: EXAMINED-NOTHING exit 78, comment-aware match, alias table (validate-ci-gates.sh) | 0 |
| `fixture-drivability` | NO-CATCH-ON-RECORD | no catch; property: consumer-side I20 fails on and names undeclared shapes (validate-fixture-drivability.sh) | 0 |
| `invariant-index` | NO-CATCH-ON-RECORD | no catch; property: --check PASS on control and near-miss, FAIL on missing index (scripts/render-invariant-index.sh) | 0 |
| `readset-sandbox-root-clause` | NO-CATCH-ON-RECORD | no catch; property: three sandbox emitters end with a no-report root allow clause (derive-fixture-readsets.sh) | 0 |
| `early-exit-reader` | NO-CATCH-ON-RECORD | no catch; property: the banned form false-passes a large input; the converted form fires (the grep -q under pipefail idiom (I54)); red on record: FIXTURE-DEFECT (decl): cannot source lib/report.sh (dirname not in tools.decl) in .20261114T114227Z.73905; batch dropped (7541acf55) | 0 |
| `fixture-hygiene` | NO-CATCH-ON-RECORD | no catch; property: the validator's verdicts on seeded probes (scripts/validate-fixture-hygiene.sh) | 0 |
| `operator-request-capture` | NO-CATCH-ON-RECORD | no catch; property: writes the operator's verbatim request at kickoff (hooks/ai-dlc-pause.sh) | 0 |
| `story-fields-derive` | NO-CATCH-ON-RECORD | no catch; property: byte-verbatim values; never clean over nothing verified (sprint-status.sh derive-stories) | 0 |
| `prepush-ssh-keepalive` | NO-CATCH-ON-RECORD | no catch; property: warns when ServerAliveInterval is 0 (core/git-hooks/pre-push KEEPALIVE) | 0 |
| `mandatory-rules-clean-tree` | NO-CATCH-ON-RECORD | no catch; property: FAILs when a required sibling is missing; PASS with retro-prereq absent (validate-mandatory-rules.sh --check-clean-tree) | 0 |
| `suite-pole-info` | NO-CATCH-ON-RECORD | no catch; property: pole info line correct for every push state (.githooks/pre-push pole_info_step) | 0 |
