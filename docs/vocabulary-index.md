# Vocabulary index

GENERATED FILE — do not edit by hand. Rendered by `scripts/render-vocabulary-index.sh` and
byte-compared at pre-push, so a controlled vocabulary cannot gain or lose a member without
this file moving with it.

Every row's members are read from the file that OWNS them at render time. This is a derived
view, not a second declaration: to change a vocabulary, change its owner and re-run the
renderer. The invariant named in each row is what holds the owner and its readers to one
set — this file reads the owner only, and where the two ever disagree the invariant is
right.

## Cross-file vocabularies

Each of these is one set spread across an owner and one or more readers, and each has an
invariant because the set kept getting restated from memory somewhere else.

| Vocabulary | Members | Owner | Bound by | Emitters | Readers |
|---|---|---|---|---|---|
| ADJUDICATED clause codes | `EXTENSION-ANCHOR-DRIFT` `EXTENSION-HOOK-DRIFT` `EXTENSION-RETIRE-CANDIDATE` `OVERRIDE-SUPERSEDED` | `core/skills/ai-dlc/layer-contract.yaml` | I58 | — | `core/skills/ai-dlc-update/reconcile/layer-drift.sh` |
| push-candidate ledger statuses | `CLOSE-CANDIDATE` `ENTRY-SWALLOWED` `HAND-REVIEW` `INPUT-UNRESOLVED` `NAMED-UPSTREAM` `NAMED-UPSTREAM-AMBIGUOUS` `NEEDS-REVIEW` `RECEIPTS-UNDECIDED` `STILL-LIVE` | `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh` | I39 | — | `core/skills/ai-dlc-update/SKILL.md`, `core/skills/ai-dlc-update/reconcile/emit-report.sh` |
| layer extension kinds | `check` `qualifier` `role` `step-domain` | `core/scripts/validate-layer-entries.sh` | I46 | — | `core/skills/ai-dlc/extensions/README.md` |
| pre-push shell-syntax globs | `.githooks/*` `core/hooks/*.sh` `core/scripts/*.sh` `core/skills/ai-dlc-update/reconcile/*.sh` `scripts/*.sh` | `.githooks/pre-push` | I30 | — | `core/git-hooks/pre-push` |
| PR classes | — consumer-owned | (consumer-owned) the taxonomy lives in THEIRS's own contract, which ai-dlc-update reads through git show rather than carrying a copy; no member of it exists in this tree to render | I70 | — | — |
| PR-class taxonomy grammar keys | `added` `capture` `class` `paths` `validator` | `core/scripts/validate-cycle-commits.sh` | I72 | — | `core/skills/ai-dlc/templates/pr-classes.md` |
| validation intensities | `carry-over-single` `full` `lightweight` `standard` | `core/skills/ai-dlc/SKILL.md` | I80 | — | `core/skills/ai-dlc/steps/route.md`, `core/skills/ai-dlc/steps/gate-validation.md` |
| empty-subject verdict token | `EXAMINED NOTHING` | `core/skills/ai-dlc/enforcement-map.yaml` | I93 | `core/scripts/validate-stub-audit.sh`, `core/scripts/validate-locked-anchor.sh`, `core/scripts/validate-ci-gates.sh`, `core/scripts/validate-artifact-paths.sh`, `core/scripts/validate-escalation-resolution.sh`, `core/scripts/validate-escalation-status-vocabulary.sh`, `core/scripts/validate-suppression-lifetime.sh`, `core/scripts/validate-gate-adjudication.sh`, `core/scripts/validate-request-coverage.sh`, `core/scripts/audit-upstream-routing.sh`, `core/scripts/audit-layer-debt.sh`, `core/scripts/validate-ac-falsifiability.sh`, `core/scripts/validate-bmad-invocations.sh`, `core/scripts/validate-spec-join.sh`, `core/scripts/validate-snapshot-conservation.sh` | `core/skills/ai-dlc/steps/gate-validation.md`, `core/skills/ai-dlc/steps/retro.md` |

## Schema enums

Every `enum` declared in `core/schemas/*.json`. Total by construction — the walker descends
each whole document, so a schema cannot gain a vocabulary this table does not show.

| Schema | Field | Members |
|---|---|---|
| `audit-anchors.json` | `close_reason` | `reset` `abandoned` |
| `gate-adjudication-verdict.json` | `verdict` | `PASS` `FAIL` |
| `layer-adjudication-register.json` | `verdict` | `still-additive` `contradicts-core` `retire` |
| `provenance-block.json` | `mode` | `solo` `subagent` |
| `provenance-block.json` | `verdict` | `EXIT_CONDITION_MET` `EXIT_CONDITION_NOT_MET` `DIVERGENT_HARD_BLOCK` |
