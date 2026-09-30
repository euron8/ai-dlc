# BRIEF — close fourteen push candidates no upstream release will discharge

**For the operator to carry into a graph session.** This is not a runbook and it authorizes no
pull. It asks the graph session to do one thing: annotate fourteen entries in its own
push-candidate ledger as closed, then rotate them to the archive. Nothing here was written to
graph; every figure below was read from graph with read-only git commands.

## Start here

- **The session's project root is `/Users/n8/git/graph`.** Every command below runs there.
- **The ledger is `_bmad-output/ai-dlc-update/push-candidate-ledger.md`.** Line numbers below are
  at graph's carry-over branch commit `737bf163` (`ai-dlc/carry-over/phase-315-aggregator-ui-cutover`).
  If the file has moved, find each entry by its `## PC-…` heading, not by line.
- **Edit only the fourteen entries named below.** Do not reword their bodies, do not delete them, and
  do not touch any other entry. A close is an annotation line, never a deletion.
- **PING THE OPERATOR** before step 3 (`--apply`) and on completion. Report which ids archived and
  which did not.

## Why eleven of them close: they name no upstream file

The ledger is the queue of work for UPSTREAM — the ai-dlc distribution. Upstream can only change
files the distribution ships. Every one of these eleven names only files the distribution does not
ship, and graph's own boundary check says so. Measured with graph's installed
`scripts/ai-dlc/core-paths.sh --is-core`, reading its stdout:

- every path the eleven entries name answers `not-core: … (no core-manifest glob matches)`, exit 1;
- positive control: `scripts/ai-dlc/derive-fixture-readsets.sh` answers `core:`, exit 0;
- negative control: `infra/lib/services-stack.ts` answers `not-core:`, exit 1.

Two entries also mention a core path, and neither asks upstream to change it:
`PC-S312-FIX-FORWARD-CLASS-GATES-ON-NO-VALIDATOR` cites `scripts/ai-dlc/validate-request-coverage.sh`
inside a retracted note that follows it, and `PC-S312-PROTECTED-CORE-PATHS-STAYS-RETIRED` names
`scripts/ai-dlc/core-paths.sh` as the replacement it already adopted.

Upstream has carried these as "not core" since its batch 169 and never told graph. They stay live
in graph's ledger, and in every upstream sweep, until graph closes them. No upstream release will
ever discharge them.

**One consequence to accept before closing.** Four entries are *falsifiability probes* — receipts
graph filed so a deletion keeps being re-tested (`…-STAYS-RETIRED`, `…-HARNESS-NOT-ABSORBED-…`).
Archiving them stops `ledger-reverify.sh` running those receipts. If graph wants the re-test to
continue, it belongs in graph's own checks (for example `scripts/ci-local.sh`), not in the upstream
queue. That is graph's decision; this brief does not make it.

## Three more that close for a different reason: upstream adjudicated them

These three ARE about core, so the reason above does not apply. Each was adjudicated upstream
against the current tree, and in each case the remedy the entry asks for was measured not to be
the fix — so no upstream release will discharge it either, and it sits in both queues forever. The
residue upstream still owes stays in upstream's own backlog under the named `BL-` entry; closing
the candidate here does not drop it.

- **`PC-S313-EMIT-REPORT-E2-IS-A-FOURTH-POOL-FLAKE-ARM`.** Filed at 0.624.0. Upstream `BL-230`
  records the E2/V-HC failure as `is_unregistered()` scoring a failed `diff` as clean, fixed in
  0.625.0; the process-substitution trigger was then removed in 0.647.0. Your entry itself calls
  this "new evidence for upstream BL-230, not a new defect class". E1, E8 and E9 stay open upstream.
- **`PC-S334-CLOSES-WHEN-NAMES-A-COMMAND-AND-NOTHING-JOINS-THE-TWO`.** The remedy (a `TRIGGERED`
  row when a `closes_when` command passes) measured 3 of 3 false positives upstream. Measured on
  this repo's own register, 655 rows: 39 owed ids, all 39 paid, and the installed
  `audit-layer-debt.sh` prints `OPEN (0) — no row declares an undischarged \`owed\` object`. There
  is no open debt a trigger could miss. Upstream keeps the field-with-no-reader residue as `BL-067`.
- **`PC-S340-SAFE-STOP-ACQUITTAL-TESTS-ANCESTRY-NOT-CONTENT`.** Both remedies the entry implies were
  measured upstream not to fire on its own case: the byte-equality arm is false at every scope above
  the executables, and the behavioural differential is vacuous on 37 of 40 hops. Your filed instance
  took the `else` branch, so the acquittal never fired on it. The one surviving direction makes the
  gate withhold MORE acquittals, which is the opposite of this entry's ask; upstream keeps it as
  `BL-132`.

## The fourteen, and the exact line to add to each

Add the annotation as a **new line directly under the entry's `## PC-…` heading**, bold, on its own
line, exactly as written. `ledger-rotate.sh` archives an entry on that bold form; no version is
required, and none should be invented.

| Line | Id | Named paths (all `not-core`) | Annotation line to add |
|---|---|---|---|
| 363 | `PC-S297-GUARDED-MERGE-PROVENANCE-INDIRECT-INVOCATION` | `.claude/hooks/guarded-merge.sh` | `**CLOSED AS REJECTED — BY DESIGN, adjudicated 2026-09-29 — guarded-merge.sh is a graph-local hook upstream deliberately does not ship (held since v0.10.0); its receipt waits for an upstream file that will never exist.**` |
| 461 | `PC-S312-RETRO-REPLAY-HARNESS-NOT-ABSORBED-BY-DRIVABILITY` | `scripts/retro-replay-harness.sh`, `scripts/ci-local.sh`, `tests/fixtures/retro-replay/seed.sh` | `**WITHDRAWN (2026-09-29) — graph-owned: the harness and ci-local.sh are not core (core-paths.sh --is-core exit 1); the entry is a keep-decision about graph's own script, not an upstream request.**` |
| 496 | `PC-S312-PROTECTED-CORE-PATHS-STAYS-RETIRED` | `scripts/check-protected-core-paths.sh` (deleted) | `**WITHDRAWN (2026-09-29) — graph-owned falsifiability probe for a graph-local deletion; upstream has nothing to change. Move the probe to graph's own checks if the re-test should continue.**` |
| 521 | `PC-S312-MUTATION-RED-ANCHOR-STAYS-RETIRED` | `scripts/check-mutation-red-anchor.sh`, `scripts/tests/test-s291-3-check35-mutation-red.sh` (deleted) | `**WITHDRAWN (2026-09-29) — graph-owned falsifiability probe for a graph-local deletion; upstream has nothing to change. Move the probe to graph's own checks if the re-test should continue.**` |
| 550 | `PC-S312-STRAY-SCAN-ARM-STAYS-RETIRED` | `scripts/ai-dlc-local/scan-stray-provenance.sh` | `**WITHDRAWN (2026-09-29) — graph-owned falsifiability probe for a graph-local excision; upstream has nothing to change. Move the probe to graph's own checks if the re-test should continue.**` |
| 577 | `PC-S312-S239-1-HARDENING-CALLS-PRE-RELOCATION-PATHS` | `scripts/ai-dlc-local/tests/test-s239-1-hardening.sh` | `**WITHDRAWN (2026-09-29) — graph-owned: the stale test is graph-local (core-paths.sh --is-core exit 1); repair or delete it in graph.**` |
| 607 | `PC-S312-FIXTURE-PROVENANCE-ARM-HAS-NO-LIVE-DRIVER` | `scripts/ai-dlc-local/scan-stray-provenance.sh`, `scripts/ai-dlc-local/tests/test-s241-5-ac4-provenance-secret.sh`, `scripts/ci-local.sh` | `**WITHDRAWN (2026-09-29) — graph-owned: the undriven arm and its test are graph-local (core-paths.sh --is-core exit 1); the keep-or-delete decision is graph's.**` |
| 629 | `PC-S312-EXPECTED-VALIDATORS-WORD-SPLIT-EXCLUDES-FLAGS` | `.claude/hooks/guarded-merge.sh`, `scripts/ai-dlc-local/lib/pr-class.sh` | `**WITHDRAWN (2026-09-29) — graph-owned: the word-split is in guarded-merge.sh and pr-class.sh, both graph-local (core-paths.sh --is-core exit 1).**` |
| 661 | `PC-S312-PR-CLASS-TEST-A6-A7-ARE-UNREACHABLE` | `scripts/ai-dlc-local/tests/test-pr-class-provenance-in-non-retro.sh` | `**WITHDRAWN (2026-09-29) — graph-owned: the dead assertions are in a graph-local test (core-paths.sh --is-core exit 1); move them above the exit 0 in graph.**` |
| 686 | `PC-S312-FIX-FORWARD-CLASS-GATES-ON-NO-VALIDATOR` | `scripts/ai-dlc-local/lib/pr-class.sh` | `**WITHDRAWN (2026-09-29) — graph-owned: the PR-class derivation is graph-local (core-paths.sh --is-core exit 1), and the entry itself proposes no change.**` |
| 1011 | `PC-S309-PRE-PUSH-FLAG-MISMATCH-ORIGINAL-TEXT` | — (a bullet-form entry: `- **PC-S309-… (superseded, retained for the record)** —`) | `**WITHDRAWN (2026-09-29) — superseded in its own heading; the text is retained for the record and asks upstream for nothing.**` |

| 739 | `PC-S334-CLOSES-WHEN-NAMES-A-COMMAND-AND-NOTHING-JOINS-THE-TWO` | — (core; see below) | `**CLOSED AS REJECTED — BY DESIGN, adjudicated 2026-09-29 — the TRIGGERED remedy measured 3 of 3 false positives upstream, and this ledger's register now carries 0 open owed debts (audit-layer-debt.sh prints OPEN (0)), so no trigger can pass unannounced; upstream keeps the residue as BL-067.**` |
| 951 | `PC-S340-SAFE-STOP-ACQUITTAL-TESTS-ANCESTRY-NOT-CONTENT` | — (core; see below) | `**CLOSED AS REJECTED — BY DESIGN, adjudicated 2026-09-29 — both remedies this entry implies (byte-equality, behavioural differential) were measured upstream not to fire on this entry's own case, which took the else branch; the surviving direction withholds acquittals rather than granting them and stays upstream as BL-132.**` |
| 1486 | `PC-S313-EMIT-REPORT-E2-IS-A-FOURTH-POOL-FLAKE-ARM` | — (core; see below) | `**WITHDRAWN (2026-09-29) — the E2/V-HC mechanism this entry observed at 0.624.0 was fixed upstream twice after filing (is_unregistered in 0.625.0, the process-substitution fd race in 0.647.0); upstream keeps the unexplained E1, E8 and E9 arms as BL-230.**` |

`PC-S309-VALIDATE-MANDATORY-RULES-CHECK5-TEST-ONLY-WEB-DIFF-FALSE-FAIL` is **not** in this set:
upstream shipped its fix in v0.542.0, so it closes as adopted, not by withdrawal. It carries no
`verify:` receipt, so re-verification skips it and cannot close it; its annotation is in
[`graph-consumer-close-brief-2.md`](graph-consumer-close-brief-2.md).

## Steps

1. Add the fourteen annotation lines above, each on its own line with a blank line above it.
   Nothing else in the file changes.
2. Dry run, which writes nothing:

   ```
   cd /Users/n8/git/graph && bash .claude/skills/ai-dlc-update/reconcile/ledger-rotate.sh \
     _bmad-output/ai-dlc-update/push-candidate-ledger.md
   ```

   Expect exactly the fourteen ids in its move list. This was rehearsed on a copy of this ledger
   at `737bf163`, using this repo's installed rotator: `14 closed entries would move`, none
   reported as not archivable, and after `--apply` the live id count fell from 31 to 17 with no
   other id moved (both 2026-09-29 `PC-S315-*` filings stayed live). If any of the fourteen
   appears under `CLOSED … but NOT archivable`, its annotation is not on its own line in bold —
   fix the line, do not reword it.
   If an id NOT in this brief appears in the move list, stop and ping.
3. **Ping the operator with the dry-run move list**, then re-run with `--apply`.
4. Verify: the fourteen entries are gone from the live ledger and present in
   `push-candidate-ledger.archive.md`; the live entry count fell by exactly fourteen.
5. Commit on graph's current branch with graph's own commit conventions. Upstream does not push
   anything to graph and does not need a reply beyond the operator's report.
