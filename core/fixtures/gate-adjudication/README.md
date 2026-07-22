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
- a **stale** verdict whose `gate_nonce` does not match its path (the freshness anchor).

## Files

- `seed.sh` — builds a pristine, COMPLETE, all-PASS verdict for the `implementation` gate in a
  fresh temp tree and prints it. The covered set is DERIVED with `--expected` (never hand-listed),
  so the fixture cannot drift from `enforcement-map.yaml`.
- `run.sh` — the 3-step proof: (a) the complete verdict passes (exit 0); (b) each corruption
  fails with the right code (1 = defect, 2 = derivation/absent); (c) restoring passes again. It
  also asserts `--expected <gate_type>` prints exactly the derived set.

## Run

    bash run.sh

Exit 0 = every assertion holds. Ships to consumers (it tests a shipped validator + schema + map),
so `run.sh` resolves both the distribution (`core/…`) and consumer (`.claude/…`, `scripts/…`)
layouts.
