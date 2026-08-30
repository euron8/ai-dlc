# predicate-sites.md — the adjudication predicates a pull must re-run over stored artifacts

Read by `reconcile/predicate-differential.sh`. Same declarative idiom as
`reconcile/setup-sites.md` and `reconcile/template-sites.md`: this file DECLARES, the script
DERIVES. Nothing here restates the pipeline rulebook, and the detector never reads it.

## What a predicate site is, and why the set is not "every validator"

An ADJUDICATION PREDICATE renders a verdict on an artifact the consumer has already STORED.
That is the whole membership rule, and it is narrower than "a script the pull changes":

- A validator that reads the consumer's SOURCE is not one. Its subject moves with the pull, so
  the pull's own diff already reports it.
- A validator the consumer's `.githooks/pre-push` invokes is not one EITHER, and this is the
  distinction that matters. `reconcile/self-update-gate.sh` already runs a differential over
  that set, deriving it from the hook. Its question is "may step 2 PUSH", its instrument is the
  EXIT CODE, and both are correct for it. A predicate site is a script whose verdicts on FROZEN
  data can change without any file in the pull's diff being wrong.

`validate-adversarial-convergence.sh` is not invoked by the reference consumer's pre-push —
measured: that hook invokes ten `scripts/ai-dlc/*.sh` and this is not one of them. So the
existing gate's population structurally excludes it, which is why this file exists rather than
one more arm there.

## Why the EXIT CODE is not the comparable verdict, measured

The first cut of the detector compared exit codes across `0.441.0..0.442.0` over the reference
consumer's corpus and reported **0 reclassifications** — a clean, plausible, wrong number. Every
series exited 1 on BOTH sides, because the probe omitted `--transcript` and this predicate fails
CLOSED without it. Sixteen series, sixteen identical pairs, and the null was two runs of a
question neither side could answer.

Comparing the NAMED ARM the predicate fails on, over the same corpus and the same refs, reports
**1 series gaining `B -- CONSISTENCY`** — the arm the reference consumer's own filing named. So
each site declares the grammar that extracts its comparable verdict, and a site whose grammar
matches nothing on BOTH sides is reported as UNDECIDABLE rather than clean.

`verdict:` is therefore a required field. A site without one cannot be compared, and the
detector refuses it instead of scoring it zero.

## Fields

- `predicate:` — path in the DISTRIBUTION, materialized at BASE and at THEIRS. Never read from
  the consumer's installed copy: the question is what the INCOMING version says.
- `corpus:` — a `find`-style name pattern, resolved under the consumer root. Consumer-relative.
- `series:` — a `sed -E` expression reducing a record path to its SERIES key. A predicate that
  adjudicates single files declares the identity expression.
- `invoke:` — the argument form, `{series}` substituted. This mirrors the form the consumer's
  own gate uses; where they disagree the CONSUMER's is right and this field is stale.
- `verdict:` — a `sed -nE` expression extracting the comparable verdict tokens from the
  predicate's combined stdout+stderr. The compared value is the SORTED SET of what it prints.

## Sites

predicate: core/scripts/validate-adversarial-convergence.sh
corpus: *pass[0-9]*
series: s/pass[0-9]+.*$/pass/
invoke: --series {series}
verdict: s/^FAIL \(([A-Z]+) --.*/\1/p
