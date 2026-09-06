# Fixture: gate-adjudication

Adversarial self-test for **Check 26** and `scripts/ai-dlc/validate-gate-adjudication.sh` — the
fail-closed reader through which a cheaper-model lead adopts the escalated `adjudication: llm`
gate checks from a fresh Opus `gate-adjudicator`.

## The bypass scenario

The verdict file is the single point where judgment is adopted. If the validator can be fooled,
a judgment check is adjudicated by no one — which reads exactly like a check that passed. The
holes this fixture proves are closed:

- a **missing** escalated check (uncovered → reads as covered);
- an **empty evidence** (an unjustified PASS);
- a **third verdict value** (`MAYBE`) where the enum is PASS/FAIL only;
- a **map adjudication typo** (`lmm`) that would silently shrink the escalated set — caught at
  the *derivation* layer, before any verdict is trusted;
- an **absent** verdict (non-delivery reading as a clean gate);
- a **stale** verdict whose `gate_nonce` does not match its path (the freshness anchor);
- an absent **`gate_series_id`** (a pass invisible to `--series` and to the stall rung).

## The SUPPRESSED carve-out (S1–S16)

A FAIL under an operator's in-force `SUPPRESSED` entry does not block, and the predicate is
asked of `validate-suppression-lifetime.sh --in-force` rather than restated here. Every way of
writing that carve-out too widely reopens something worse, so each hole gets its own case:

- **S1** the carve-out is REACHABLE at all: an in-force entry naming the failing check → exit 0.
- **S2** it is keyed on the CHECK, not on the gate: the same entry, a FAIL on another check → exit 1.
- **S2b** the ALLOW twin of S2 — both fail, one covered → exit 1 naming only the uncovered one.
- **S3** an EXPIRED entry (2 gates recorded against a 1-gate lifetime) → exit 1.
- **S4** a MALFORMED entry, no `**Operator authorization:**` → exit 1.
- **S5** the corpus's real shape: the suppression fields under `DECIDED_AUTONOMOUSLY` → exit 1.
- **S6** a FOREIGN catalog (`[extension:foo]`) → exit 1; and the id-only form with no `[catalog]`
  prefix, which the lifetime parser already accepts → exit 0.
- **S7** no escalations file: fail-closed, and the block names `no-escalations-file`.
- **S8** a terminal entry whose PROSE names the check and which suppresses nothing → exit 1
  (kills a carve-out written as a grep over `pending.md`).
- **S9** the mirror of S6: the entry is core's, the VERDICT's catalog is an extension's → exit 1.
- **S10** an all-PASS verdict with an in-force entry present → the `all PASS)` line, unchanged.
- **S11** an entry naming a PREFIX of the failing id → exit 1 (no substring or prefix match).
- **S12** the other half of S6: the bare-id entry against a verdict whose catalog is an
  extension's → exit 1. A row with no `[catalog]` counts as `core` and nothing else, so a
  dropped bracket cannot buy wider coverage than writing it correctly would.
- **S13** one malformed entry beside one well-formed in-force entry, in the SAME file → exit 0
  with the SUPPRESSED line. Every other case's file holds a single entry, so only this one can
  tell "this ENTRY is excluded" from "this FILE is refused".
- **S14** the expired entry with the timeline pointed at a MISSING file → exit 1. A lifetime
  that cannot be counted is not a licence.
- **S15** its ALLOW twin: an EXISTING but empty timeline is a consumer that has run no gate
  yet, and its fresh suppression is in force at 0 elapsed → exit 0.
- **S16** an all-PASS verdict does not ASK the sibling at all — no `IN-FORCE:` line on stderr.
- **S17** the gate timeline is located from the PROJECT ROOT, never from the process cwd.

## The citation is VERIFIED (S18–S22)

The sibling checks that `**Operator authorization:**` carries a timestamp and a quote; the
validator verifies the quote against the transcript corpus its `--transcript-dir` names with
`validate-steering-budget.sh --cite` — the same predicate the remediation guard applies to the
same rows — before a row can cover anything. Without these, a lead could write its own gate
passage into `pending.md` and the gate adopted it.

- **S18** the words are in the corpus only in an assistant turn and a tool_result → exit 1,
  `unverified-citation: 1` (kills a verifier written as a grep over the corpus).
- **S19** neither `--transcript` nor `--transcript-dir` given → exit 1, `no-transcript`.
- **S20** the `--transcript` single-file fallback verifies a genuine quote → exit 0.
- **S21** `--transcript-dir` naming a directory with no `*.jsonl` → exit 1, `no-transcript`.
- **S22** two entries, one genuine and one forged, both checks failing → exit 1 naming only the
  forged entry's check, with the genuine one still `SUPPRESSED`: rows are narrowed, not dropped.

Each case asserts a TOKEN as well as an exit code — the `SUPPRESSED —` line, the block's
`no-escalations-file` or `no-transcript`, or the sibling's own `in_force=` count — because an
exit code alone cannot tell a carve-out that fired for the right reason from a validator that
never looked. All three channels (`AI_DLC_ESCALATIONS`, `AI_DLC_GATE_METRICS`,
`--transcript-dir`) are set explicitly on every case: a consumer's real
`docs/escalations/pending.md` holds real in-force suppressions, and a case that inherits the
default is adjudicated against whatever that consumer suppressed this week.

`core/fixtures/gate-adjudication-mutants/` scores these cases against thirteen wrong fixes and
an unmutated control, and asserts for each one exactly which cases go red.

## Files

- `seed.sh` — builds a pristine, COMPLETE, all-PASS verdict for the `implementation` gate in a
  fresh temp tree and prints it. The covered set is DERIVED with `--expected` (never hand-listed),
  so the fixture cannot drift from `enforcement-map.yaml`. It also seeds the escalations files
  and two gate timelines the carve-out cases need; the three check ids those entries name are
  derived from the same escalated set, so a map that moves cannot leave a case naming a check
  the gate no longer adjudicates. Both JSON spacings appear in every timeline.
- `run.sh` — the 3-step proof: (a) the complete verdict passes (exit 0); (b) each corruption
  fails with the right code (1 = defect, 2 = derivation/absent); (c) restoring passes again. It
  also asserts `--expected <gate_type>` prints exactly the derived set.

## Run

    bash run.sh

Exit 0 = every assertion holds. Ships to consumers (it tests a shipped validator + schema + map),
so `run.sh` resolves both the distribution (`core/…`) and consumer (`.claude/…`, `scripts/…`)
layouts.
