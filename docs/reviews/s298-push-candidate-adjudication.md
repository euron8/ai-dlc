# Push-candidate adjudication — graph ledger, 2026-07-24

Every entry in the graph consumer's `_bmad-output/ai-dlc-update/push-candidate-ledger.md`
was re-verified against ai-dlc HEAD (v0.140.0, `e86904f`). The consumer is stamped at that
exact commit, so nothing here is stale-pending-pull: an entry that reports open is open
against current distribution.

This document is the upstream half. The consumer owns its own ledger; nothing here edits the
graph repo.

**The headline is not the backlog, it is the instrument.** The first run classified 19 of 32
entries `NEEDS-REVIEW` — 59% of every entry carrying a machine-runnable predicate was never
actually tested. Repairing `ledger-reverify.sh` (v0.141.0, this batch) took that to 10, and
in the process surfaced **six entries the ledger would have reported as absorbed upstream
when all six are live defects**, plus one live-forever entry upstream had already fixed.

## What the run says now

| verdict | before | after | meaning |
|---|---|---|---|
| STILL-LIVE | 13 | **18** | predicate ran, entry reproduces at HEAD — valid backlog |
| HAND-REVIEW | — | **4** | `verify: manual`; no mechanical predicate by design |
| NEEDS-REVIEW | 19 | **10** | predicate could not be trusted to run |
| CLOSE-CANDIDATE | 0 | **0** | correct: nothing upstream changed since the consumer's stamp |

Reproduce with:

```
core/skills/ai-dlc-update/reconcile/ledger-reverify.sh \
  /Users/n8/git/ai-dlc e86904f /Users/n8/git/graph e86904f
```

## Three defects in the instrument, not the ledger

**1. Path namespace (15 entries).** The `verify:` paths were filed in the consumer's INSTALL
layout prefixed with `core/` — `core/.claude/skills/ai-dlc/steps/gate-validation.md`,
`core/scripts/ai-dlc/validate-locked-anchor.sh`, `core/tests/fixtures/…`. Distribution layout
is `core/skills/…`, `core/scripts/…`, `core/fixtures/…`. None resolved, so no substring was
ever compared. The closer now retries by basename across the tree at `theirs` and takes the
match only when it is unique; 12 entries became verifiable, and 3 correctly stayed
`NEEDS-REVIEW` because their basename is ambiguous (`seed.sh` exists in every fixture) or
absent.

**2. Vacuous predicates (7 entries) — the serious one.** A `theirs_has "<substr>"` predicate
closes when the substring is gone at `theirs`. If the substring was never at BASE either, the
predicate could never have reported STILL-LIVE: it was born closed, and no upstream change
produced the verdict.

Six S297 entries have exactly this shape, all from the same authoring slip — the substring
names the **fix** the entry wants, paired with the verb that means the opposite:

| entry | substring | should be |
|---|---|---|
| `PROVENANCE-FLAGLESS-FAIL-OPEN-BY-DEFAULT` | `"fail-closed by default"` | `theirs_lacks` |
| `LOCKED-ANCHOR-BYTE-MATCH-IGNORES-THE-ANCHOR` | `"anchor-scoped byte-match window"` | `theirs_lacks` |
| `LOCKED-ANCHOR-EXEMPTED-BY-SILENCE` | `"claims_checked=0 explicit non-defect note"` | `theirs_lacks` |
| `VALIDATE-MANDATORY-RULES-CHECK3-CHECK4-DEAD` | `"Check 3 and Check 4 real enforcers"` | `theirs_lacks` |
| `CHECK16-SCOPE-AMBIGUITY` | `"Check 16 added-lines-only"` | `theirs_lacks` |
| `RETRO-UPSTREAM-PM-AC-PRECISION` | `"verify shape before locking AC"` | `theirs_lacks` |

Each entry's own body confirms the defect is still present — `CHECK16-SCOPE-AMBIGUITY` states
outright that `gate-validation.md:841` still reads the ambiguous text. **Had the closer been
believed, a drain would have closed six live defects**, and each would have read as an
ordinary absorbed-upstream close. The closer now checks both refs before emitting any close
and reports a predicate that could not have fired instead of obeying it.

**3. Multi-substring directives (2 entries).** `verify: theirs_lacks <path> "A" "B"` is not in
the convention. The parser joined the run into one literal *including the quotes between the
substrings*, which matches nothing — so the entry reported "still lacks" forever regardless of
what `theirs` held. One of the two, `GATE-PROCEDURES-DISPATCH-NOT-MANDATED-BACKGROUND`, names
two markers `_gate-procedures.md` **already carries**: it would have sat open permanently
against an upstream that had absorbed it. Substrings are now matched individually (AND); the
single-substring form is the one-element case and is unchanged.

## Bucket 1 — valid, 18 machine-confirmed live

Grouped for batching. These are the real upstream backlog; **none is fixed in this batch.**

**Validator hardening (6)**
- `validate-ci-gates.sh` — dormant-gate scan needs repointing at a real enforcer (`run_check`)
- `validate-retro-evidence.sh` — resolve the retro branch via `origin/…`
- `validate-mandatory-rules.sh` — subset-mode flags + shared `gate_log_rotation_ok`
- `validate-locked-anchor.sh` — `requires_context`-only case never byte-matched against source
- `validate-steering-budget.sh` — Check 25 accepts an unbound `--transcript`
- `PC-S296-H1-FIXTURE-CITATION-GAP` — five H1-enumerated checks lack a fixture cross-reference

**Rule text (2)** — both are the same Rule 18 gap, in two homes; fix together or the pair drifts.
- `SKILL.md` — no carve-out for terse traceability citations (`identifier tag`)
- `rule-authoring.md` — `stable identifier` tags

**Step-file gate semantics (7)**
- `PC-S295-RETRO-STEP5C-DEADLOCK-ON-DEFERRED-RED` — with `deploy-validate.md`'s "Repeat until
  all smoke tests pass." These two are one fix; the entry itself argues a shared gate outcome
  rather than two reworded steps.
- `PC-S295-RETRO-CHECK5-SELF-REFERENTIAL` — Check 5 compares two hand-maintained mirrors and
  cannot fail
- `PC-S295-RETRO-LEAD-SOLO-EVAL-LLM-CHECK` — no rule forbids the lead solo-evaluating
- `PC-S295-RETRO-RED-SMOKE-CROSSING-SPRINT-BOUNDARY` — "pre-existing FAILs may persist"
- `sprint-review` §3 decision-branch execution-coverage
- `PC-S297-CHECK16-ELEMENT2-REGEX-DEAD` — second stub-marker regex never matches live content
- `PC-S297-CHECK17-PRD-ARM-CONTRADICTS-RULE-20-BLOCK-PLACEMENT`

**Reconcile machinery / docs (3)**
- `PC-S296-REJECTION-CARRIES-UNRELATED-GAPS` — `classify-block.md`
- `PC-S297-POOL-LOOP-SUBSHELL-TRAP-UNDOCUMENTED` — `validate-artifact-budget.sh`
- `PC-S297-RETRO-MD-CLAIMS-NONEXISTENT-GHA-WORKFLOW` — `retro.md` cites a
  `.github/workflows/*.yml` that does not exist

## Bucket 2 — needs body adjudication, 10

Seven are the vacuous predicates above: **treat every one as live until its body is read**,
and do not drain on the closer's word. Three could not be resolved at all and need the path
corrected before any machine verdict is possible:

- `PC-S297-FFCLUSTER-SHA-STALE` — `deploy-validate-push-sha-repin.sh` exists nowhere in core
- `PC-S297-GUARDED-MERGE-PROVENANCE-INDIRECT-INVOCATION` — `guarded-merge.sh` is a
  consumer-provided hook, absent from core
- `PC-S297-H2-SEEDS-STILL-VACUOUS-PURE-ECHO` — `seed.sh` is ambiguous by basename; the entry
  means `core/fixtures/check-h1-recursion/seed.sh`

The first two reference artifacts with no core equivalent. They are consumer-only and should
be drained from the push-candidate section rather than fixed upstream — but that is the
consumer's edit to make, not this document's.

## Bucket 3 — hand-review by declaration, 4

`verify: manual` entries, now reported as `HAND-REVIEW` rather than filed alongside malformed
lines: the S295 three-axis disposition block, `LOCKED-FENCE-LAUNDERS-AGENT-PROSE`,
`VALIDATOR-PASS-VS-NOTHING-TO-CHECK-CONVENTION`, `RETRO-OVERRIDES-F1F2F3F6`.

## Owed back to the consumer

Not actionable upstream; recorded here for the operator to deliver via `ai-dlc-update`.

1. **Correct the 15 `verify:` paths to distribution-relative form.** The basename fallback
   makes them work today, but it declines ambiguous basenames — `seed.sh` is already failing
   that way, and every future fixture entry will too.
2. **Fix the six inverted verbs** to `theirs_lacks`. The vacuity guard now reports them
   instead of closing them, so nothing is at risk; the entries are simply parked until the
   predicate says what the body means.
3. **`_bmad-output/implementation-artifacts/sprint-status/_preamble.yaml` is 40,827 tokens.**
   Larger than `audit-anchors.md` was before this batch bounded it. The sharded
   `sprint-status/` layout and the `_preamble.yaml` name are consumer-local — neither appears
   anywhere in core — so core's budget table cannot govern it. Worth the same question core
   just answered for its own anchors: what actually reads it, and how deep?
4. **Three unbudgeted read-path artifacts** now surface from `validate-artifact-budget.sh`'s
   new coverage guard: `brownfield-inventory.md` (4,806 tok), `bug-analysis.md` (5,253),
   `test-strategy.md` (2,883). All three are rewritten per run rather than appended, so none
   is an unbounded-growth defect — but none is measured either, and that is now visible.
