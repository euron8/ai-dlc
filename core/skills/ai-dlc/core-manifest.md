<!-- CORE_MANIFEST v1 -->
# Core manifest — the upstream-owned file set

This file is the single source of truth for the **core** layer (Rule 27):
the upstream-owned files `/ai-dlc-update` overwrites wholesale and that a
consumer MUST NOT edit in place. The gate-validation **Core-layer
immutability** check, the edit-time `ai-dlc-core-guard.sh` hook, and Rule 27
all read this list rather than enumerating it inline, so the set is defined
in exactly one place on the pipeline side.

**Layer grain is DECLARED, in the `machinery:` and `rulebook:` lists below.** A
`rulebook` entry is consumer-readable prose: a change to one goes into a consumer
layer (`overrides/` to shadow a rule, `extensions/` to add one). A `machinery`
entry has **no layer grain** — there is no `overrides/` or `extensions/` entry
for a hook, a validator, a schema, a template or the update engine. It is
upstream-owned like the rest, but a consumer that needs different behavior
configures it through the declared `AI_DLC_*` tunables or takes the change
upstream. The core-guard routes on this distinction, and `ai-dlc-update`'s
self-update cycle pulls the machinery set autonomously, because a file with no
layer grain has nothing for an operator to adjudicate.

The two lists PARTITION every non-`fixtures/` entry: `validate-enforcement-map.sh`
fails if one is in neither or both, so a new entry cannot be added without
classifying it. `fixtures/` entries are machinery by category — test data has no
layer grain either — and are excluded from the partition because their own
enumeration is derived. This was prose-only until it was declared, and the prose
had already rotted: it omitted `templates/*.md`.

**An unclaimed core subtree fails in both directions.** It carries no edit-time
protection, so a consumer can edit it in place and the next pull either clobbers
the change or raises a false BOTH-CHANGED conflict. And Check 16's stub audit asks
this list whether a marker sits in an upstream-owned file, so an unclaimed core
file is audited as consumer-authored — a bar it can never clear, because a core
file cannot carry a consumer backlog item and the guard denies the edit that would
add one. Every subtree `install.sh` overwrites wholesale MUST appear below.

**Every entry is a glob over a directory that is exclusively ours.** A glob names
our set only where that holds. `scripts/` does not hold it — a consumer's own audit
scripts sit beside ours under no distinguishing prefix — so core scripts have a
directory of their own, `scripts/ai-dlc/`, and the manifest claims all of it. The
same rule governs any new entry: where a directory is shared, give core its own
directory inside it rather than listing the files we own there. Do NOT enumerate
what a glob can name.

**A file in `scripts/ai-dlc/` is core whether or not the distribution ships that
name.** The directory is the boundary, not the file list, so the guard denies an
in-place edit AND denies the `Write` that would create such a file, routing the
author to `scripts/ai-dlc-local/`. `core-script-boundary`'s assertion 8 asserts all
three directions.

**Fixtures are the one entry set that must be enumerated, and the enumeration is
DERIVED.** `tests/fixtures/` is genuinely shared: core ships its adversarial
self-tests there and a consumer's own fixtures sit beside them under no
distinguishing prefix — in the reference consumer, core and consumer directories
both use the `check-` prefix, so no glob separates them. Until they have a
directory of their own, one entry per shipped fixture is the only expressible form.
Nothing here is hand-maintained: the set is `core/fixtures/` minus every directory
carrying a `.dist-only` marker, which is the same derivation `install.sh`'s loop and
`validate-enforcement-map.sh` I8 already use. I8 asserts the entries below equal
that set in both directions, so a new fixture cannot ship unclaimed and a claimed
name cannot outlive its fixture.

**A core fixture's content IS its assertion's input.** The stub markers, anchor
counts and deliberately-malformed stanzas inside a fixture are the payload the
`run.sh` beside it reads, so an edit that looks like tidying can leave the fixture
passing while it proves nothing — and nothing downstream can tell a vacated fixture
from a working one. There is no `overrides/` shadow for a seed and no `extensions/`
entry for an assertion; the guard routes accordingly. A consumer's own fixtures go
in `tests/fixtures/<their-own-name>/`, which core never reads, never writes and
never overwrites, and which the pre-push suite drives exactly the same way.

**Consumer-authored ai-dlc scripts do not belong there.** A consumer's own
pipeline tooling — snapshot resets, dormant-gate audits, sprint-entry sweeps —
goes in the **consumer machinery home**, which core never reads, never writes and
never overwrites. The two directories differ by ownership, not by subject.

**The home is DECLARED, as `consumer_machinery_home:` below, because it was
advertised in five places and declared in none.** The core-guard names it in the
deny text that routes an author there, `reconcile/warn-shadowed-local-validators.sh`
defaults to it, two fixtures write into it, and this file said it in prose — five
independent spellings of one path, joined by nothing. That is the shape I26 exists
to catch: a value restated at each reader instead of derived from one home.
`validate-enforcement-map.sh` **I43** now binds every spelling in both directions —
a surface naming a different `scripts/ai-dlc*` path fails the build, and so does a
declared home the guard's deny text never routes to, because a home no affordance
points at is one no author finds. **I44** asserts the never-writes half: nothing
`install.sh` copies, nothing `uninstall.sh` removes, and no `core_manifest:` entry
resolves under it.

The home's INTERNAL layout is the consumer's. Core makes no claim about which
subdirectories exist inside it, and the one reader that walks it searches the whole
tree rather than a declared subdirectory list — a list core cannot enforce is one
more restatement.

**Only the `ai-dlc-*` hooks are core.** The glob is `hooks/ai-dlc-*.sh`, not
`hooks/*.sh`: a consumer may ship its OWN hooks alongside the core set. Those are
consumer-owned — the guard MUST NOT deny an edit to them and the immutability
check MUST NOT flag them. Every hook `/ai-dlc-update` ships carries the
`ai-dlc-` prefix; the prefix is the boundary.

Paths are relative to the ai-dlc skill directory
(`.claude/skills/ai-dlc/` in a consumer, `core/skills/ai-dlc/` upstream),
except these prefixes, which resolve outside it:

| entry prefix       | consumer path                    |
|--------------------|----------------------------------|
| `team-roles/`      | `.claude/team-roles/`            |
| `hooks/`           | `.claude/hooks/`                 |
| `session-driver/`  | `.claude/session-driver/`        |
| `schemas/`         | `.claude/schemas/`               |
| `skills/`          | `.claude/skills/`                |
| `scripts/`         | `scripts/` (project root)        |
| `fixtures/`        | `tests/fixtures/` (project root) |
| `git-hooks/`       | `.githooks/` (project root)      |

`to_consumer_glob()` is the one implementation of that mapping. It lives in
`hooks/ai-dlc-core-guard.sh` (edit-time) and `scripts/ai-dlc/core-paths.sh`
(everything else, including Check 16's scope filter), byte-identical by
assertion — `validate-enforcement-map.sh` I25 fails the build if they fork,
because a mapping that differs between them lets the gate exempt what the guard
protects.

```yaml
core_manifest:
  - core-manifest.md
  - enforcement-map.yaml
  - layer-contract.yaml
  - git-hooks/pre-push
  - SKILL.md
  - steps/*.md
  - escalations.md
  - rule-authoring.md
  - templates/*.md
  - team-roles/*.md
  - hooks/ai-dlc-*.sh
  - session-driver/*.sh
  - schemas/*.json
  - skills/ai-dlc-setup/**
  - skills/ai-dlc-update/**
  - scripts/ai-dlc/*
  - fixtures/adversarial-citation/**
  - fixtures/apply-drift-after-write/**
  - fixtures/apply-drift-refile/**
  - fixtures/apply-legacy-script-path/**
  - fixtures/apply-restamp-theirs/**
  - fixtures/askuserquestion-citation/**
  - fixtures/command-args-citation/**
  - fixtures/operator-request-capture/**
  - fixtures/request-coverage/**
  - fixtures/scope-confirmation/**
  - fixtures/snapshot-conservation/**
  - fixtures/suppression-lifetime/**
  - fixtures/self-update-join-gate/**
  - fixtures/self-update-fixture-log/**
  - fixtures/audit-anchors-schema/**
  - fixtures/blocker-adjudication-record/**
  - fixtures/bmad-invocation-resolve/**
  - fixtures/check-15-bypass/**
  - fixtures/check-17-bypass/**
  - fixtures/check-17-counts/**
  - fixtures/check-1c-bypass/**
  - fixtures/check-23-draft-stamps/**
  - fixtures/check-24-adversarial-convergence/**
  - fixtures/check-25-steering-conduct/**
  - fixtures/check-31-ac-falsifiability/**
  - fixtures/check-3b-locked-anchor/**
  - fixtures/check-h1-recursion/**
  - fixtures/check-manifest-bypass/**
  - fixtures/check5-anchor-base/**
  - fixtures/check-22-spawn-ledger/**
  - fixtures/ci-gates-resolution/**
  - fixtures/consumer-machinery-home/**
  - fixtures/consumer-suite-pool/**
  - fixtures/layer-qualifier-grain/**
  - fixtures/layer-conforms-to/**
  - fixtures/layer-extends-grain/**
  - fixtures/layer-retired-id-crosswalk/**
  - fixtures/layer-crosswalk-home/**
  - fixtures/layer-reference-resolution/**
  - fixtures/layer-adjudication-tier/**
  - fixtures/layer-title-join/**
  - fixtures/context-mode-protect/**
  - fixtures/context-sensor/**
  - fixtures/core-paths-audit-diff/**
  - fixtures/core-script-boundary/**
  - fixtures/core-write-guard/**
  - fixtures/cycle-commits-enforce/**
  - fixtures/dispatch-model-guard/**
  - fixtures/divergence-hard-block/**
  - fixtures/escalation-citation/**
  - fixtures/extension-check-adoption/**
  - fixtures/escalation-status-vocabulary/**
  - fixtures/gate-adjudication/**
  - fixtures/gate-verdict-grep-shape/**
  - fixtures/h2-attest-scripts-dir/**
  - fixtures/handoff-resume-guard/**
  - fixtures/implementation-join-yield/**
  - fixtures/inflight-row-shape/**
  - fixtures/known-skills-extension/**
  - fixtures/layer-anchor-declaration/**
  - fixtures/layer-catalog-collision/**
  - fixtures/layer-contract-conformance/**
  - fixtures/layer-debt-ledger/**
  - fixtures/layer-readopt-gate/**
  - fixtures/ledger-reverify/**
  - fixtures/ledger-status-vocabulary/**
  - fixtures/ledger-reverify-unfalsifiable/**
  - fixtures/fixture-drivability/**
  - fixtures/ledger-rotate/**
  - fixtures/mandatory-rules-clean-tree/**
  - fixtures/mutation-red-replay/**
  - fixtures/trunk-audit-classes/**
  - fixtures/story-fields-derive/**
  - fixtures/trunk-push-bound/**
  - fixtures/pause-hook-origin/**
  - fixtures/postcompact-rulebook-recovery/**
  - fixtures/provenance-not-accessible/**
  - fixtures/reconcile-blocking-list/**
  - fixtures/reconcile-emit-report/**
  - fixtures/relabel-theirs-collision/**
  - fixtures/release-version-triple/**
  - fixtures/relocation-preclassify/**
  - fixtures/resume-whole-read/**
  - fixtures/retired-contract-token/**
  - fixtures/retired-layer-contract/**
  - fixtures/retired-fixture-orphan/**
  - fixtures/consumer-machinery-inventory/**
  - fixtures/retro-audit-scans/**
  - fixtures/route-defect-classification/**
  - fixtures/self-update-gate/**
  - fixtures/setup-config-drift/**
  - fixtures/shadowed-local-validators/**
  - fixtures/snapshot-evidence-cell/**
  - fixtures/snapshot-section-schema/**
  - fixtures/spec-adoption-floor/**
  - fixtures/spec-join-integrity/**
  - fixtures/sprint-status-lifecycle/**
  - fixtures/story-provenance/**
  - fixtures/stray-party-mode-provenance/**
  - fixtures/subagent-probe/**
  - fixtures/taught-schema/**
  - fixtures/validate-mandatory-rules-revive/**
  - fixtures/validator-path-resolution/**
  - fixtures/verdict-pass-content/**
  - fixtures/wait-stale-deliverable/**
  - fixtures/whole-read-pool/**

machinery:
  - core-manifest.md
  - enforcement-map.yaml
  - layer-contract.yaml
  - git-hooks/pre-push
  - templates/*.md
  - hooks/ai-dlc-*.sh
  - session-driver/*.sh
  - schemas/*.json
  - skills/ai-dlc-setup/**
  - skills/ai-dlc-update/**
  - scripts/ai-dlc/*

rulebook:
  - SKILL.md
  - steps/*.md
  - escalations.md
  - rule-authoring.md
  - team-roles/*.md

consumer_machinery_home: scripts/ai-dlc-local/
consumer_machinery_subdirs: lib/ hooks/ fixtures/ config/ tests/
```

**Note on the second copy.** `ai-dlc-update`'s
`reconcile/setup-sites.md` carries its own duplicate of this list by
design — a HARD CONSTRAINT keeps that skill self-contained and forbids it
from reading pipeline files. The two lists MUST be kept in sync when the
core file set changes; they are the only two authoritative copies.
