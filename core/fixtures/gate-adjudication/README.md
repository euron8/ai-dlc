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
- **S20** `--transcript` naming a file that does NOT carry the quote, whose sibling does → exit 0:
  the file is widened to its directory, as the remediation guard widens the session transcript.
- **S21** `--transcript-dir` naming a directory with no `*.jsonl` → exit 1, `no-transcript`.
- **S22** two entries, one genuine and one forged, both checks failing → exit 1 naming only the
  forged entry's check, with the genuine one still `SUPPRESSED`: rows are narrowed, not dropped.
- **S23** the verifier cannot run (node off PATH, asserted first) → exit 1, `verifier-error: 1`,
  and NOT the forgery sentence: a tooling failure covers nothing and is reported as one.

The ALLOW corpus holds TWO transcripts with the quote in the second by glob order, because a
verifier that scans the first member and stops passed every case and the receipt when it held
one — and reads NOMATCH on the reference consumer's one genuine in-force citation.

Each case asserts a TOKEN as well as an exit code — the `SUPPRESSED —` line, the block's
`no-escalations-file` or `no-transcript`, or the sibling's own `in_force=` count — because an
exit code alone cannot tell a carve-out that fired for the right reason from a validator that
never looked. All three channels (`AI_DLC_ESCALATIONS`, `AI_DLC_GATE_METRICS`,
`--transcript-dir`) are set explicitly on every case: a consumer's real
`docs/escalations/pending.md` holds real in-force suppressions, and a case that inherits the
default is adjudicated against whatever that consumer suppressed this week.

`core/fixtures/gate-adjudication-mutants/` scores these cases against thirteen wrong fixes and
an unmutated control, and asserts for each one exactly which cases go red.

## The `--coverage` mode (C0–C8, CV-M0/MA/MB/MC)

The `gate-adjudicator` runs `--coverage <gate_type> <verdict_path>` on the file it just wrote,
before returning the path. It runs the envelope arms and the coverage join and stops, so a
dropped escalated id costs a same-dispatch fix instead of the whole new dispatch the lead's run
would force. The danger is that it becomes a SECOND program with its own grammar, and then the
adjudicator self-checks against a rule the lead does not apply.

- **C0** the three worlds these arms are driven over (complete / short one id / nonce off its
  own stem) are asserted to differ from one another before any predicate is read.
- **C1** a complete all-PASS verdict → exit 0 **with the `COVERAGE-OK` line**. Every exit-0 arm
  here is presence-shaped: exit 0 is also what an ignored flag produces.
- **C2** the discriminating seed — one check `FAIL` with non-empty evidence → `--coverage` 0 and
  the full mode 1, asserted in the SAME arm and required to differ. A mode that re-ran the gate
  would pass every other arm in this section while sending the adjudicator back to edit a
  correct verdict.
- **C3** an escalated id dropped → exit 1 naming the check; **C3-bind** the coverage mode's
  `block()` text and the full mode's, for the same file, are byte-identical (control: a nonsense
  string does not compare equal). One body, two callers, asserted as bytes — two modes that
  print different text for one defect would both still exit 1, and nothing else here would
  notice. The comparison is keyed on the `block()` emission and not the whole stream, because
  the carve-out's sibling writes above it: whole-stream, this arm joined `m13`'s kill set in
  `gate-adjudication-mutants` for a reason unrelated to the coverage join.
- **C4** an id outside the escalated set → exit 1. The other direction of the join; a mode
  asking only "is every expected id present" lets the adjudicator invent a check.
- **C5** an absent path → exit 2 and a DIRECTORY → exit 2, with the real verdict in the same
  invocation shape → exit 0. Non-delivery is a different claim from a defective verdict, and
  the control is what says the 2s are not a mode that refuses everything.
- **C6** the wrong-path binding: a `gate_nonce` that is not its filename stem → exit 1 with the
  NONCE sentence and NOT the coverage one, on a file that is ALSO short. Both sentences are
  reachable for that input, so the arm discriminates on which arm fired rather than on the exit.
- **C7** the binding arm is EXCLUDED: a fully-covered all-PASS verdict whose nonce nothing binds
  → `--coverage` 0, full mode 1 (`bound to NO dispatch`), sides asserted to differ. An EMPTY
  sandbox does not build this world — no ledger at all yields `nocorpus`, which the binding arm
  acquits, so the full side reads 0 and the pair proves nothing; the seed carries a spawn ledger
  and a `.verdict-writes.jsonl` whose rows all predate the nonce.
- **C8** the near-miss C7 requires: the SAME unbound world, one id short → exit 1 naming the
  missing check. Without it, "coverage exits 0 on an unbound verdict" is satisfied by a mode
  that exits 0 on everything the binding arm would have refused — which is the masking measured
  on four real consumer verdicts and the reason this mode exists.

Three mutants score C3, C6 and C7, because each of those is a claim that one NAMED arm owns one
input and each would pass against a mode reaching the right exit for the wrong reason. Each
mutant is built as a copy of the validator plus the three siblings it resolves beside itself,
the anchor's occurrence count asserted at exactly 1 and the copy `cmp -s`-asserted to differ,
and each is scored with the ARM'S OWN predicate against ALL THREE — a mutant that kills more
than its own has an entangled assertion, one that kills none was not built.

- **CV-M0** the unmutated copy: all three predicates hold, so every kill below is attributable
  to a mutation rather than to a copy that could not run.
- **CV-MA** `_cov_fails = []` — the mode runs the envelope, prints the line, never asks the
  question → killed by C3's predicate alone.
- **CV-MB** the nonce/stem arm skipped in this mode → killed by C6's predicate alone.
- **CV-MC** the mode's exit moved BELOW the dispatch binding — the reshape that reads as a
  simplification and re-imposes an exit no edit to the adjudicator's own file can clear →
  killed by C7's predicate alone. Two edits, both the mutation: the delete alone leaves the
  mode falling through to the full program, which is a different mutant. The insert's anchor
  carries a leading newline because `fails = coverage_arms()` appears twice in the file.

## Script arms before the adjudicator

The last arm reads the two step files rather than the validator, because the defect it guards
is a prose one: a script-arm FAIL found AFTER the `gate-adjudicator` had been dispatched sent
the lead to Gate Failure step 2, whose only reachable sentence told it to re-run the full
escalated set — so the consumer ran the full escalated set twice for a script FAIL found after
dispatch. The repair has two halves and the arm asserts both. `gate-validation.md` and
`_gate-procedures.md` must each carry **Script arms before the adjudicator**, so the ordering
cannot hold in the gate's own file while the dispatch procedure it references still says
otherwise. And in `gate-validation.md`'s Gate Failure block, `re-derives the full escalated set
at a fresh` must be present with the `pipeline-snapshot-history.md` lead-repair exemption
beside it, while `whose inputs the remediation touched` must survive NOWHERE in that file.

That last assertion is FILE-WIDE and not block-scoped, deliberately: the clause is an
instruction, and a copy of it anywhere in the gate's own step file is one the lead can read and
follow. A **near-miss probe plants it after `## Gate Reset` and REQUIRES the assertion to
fail** — narrowing the grep to the block is what would make that probe green, so the arm
carries its own refusal of the narrowing. Three further probes delete the preamble clause from
each file in turn and revert step 2 to the old wording, each against a synthesised control copy
that carries every property and must PASS the same five predicates. The control is what
separates a probe set that discriminates from one that refuses everything; all of them are
built as copies under the seed's work tree, `cmp -s`-guarded against the copy they were derived
from, and run BEFORE the corpus is read. The corpus's absence assertion carries a positive
control in the same invocation — the `CHECK_LOADED: failure` marker, demanded exactly once — so
a zero from an empty or mis-resolved file cannot read as a clause that is gone.

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
