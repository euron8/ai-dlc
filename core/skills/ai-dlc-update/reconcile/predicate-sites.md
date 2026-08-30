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

## A PREDICATE IS ITS READ-SET, NEVER ITS SCRIPT, AND THE SCRIPT-ONLY FORM IS VACUOUS

The first cut of this file declared one `predicate:` path and the detector compared that file at
the two refs. **For a predicate that carries its thresholds inline that is correct, and for one
that resolves a SCHEMA at runtime it is a confident wrong clean.**

`core/scripts/validate-provenance-block.sh:16` says so in its own header — *"THE SCHEMA IS NOT IN
THIS FILE"* — and resolves `.claude/schemas/provenance-block.json` at runtime at its lines
118-120. (That is the CONSUMER path, which is the one a reader of this file needs: `install.sh`
lands `core/schemas/` at `.claude/schemas/`, so a bare `schemas/…` pointer resolves against the
skill root and is dead in every installed tree. The `reads:` globs below are DIST-relative
because they are resolved with `git ls-files` against the distribution, which is a different
question from where the file lives once installed.)
`validate-gate-adjudication.sh` reads `gate-adjudication-verdict.json` the same way.

**The dated instance: `v0.382.0` (`d71d981e`) changed `core/schemas/provenance-block.json` and
left `core/scripts/validate-provenance-block.sh` BYTE-IDENTICAL** — md5 `8d27d35c…` on both sides,
schema `c7154cf6…` -> `29528de5…`. A script-only differential across that range hits the
sides-identical arm and reports `PREDICATE-STABLE, byte-identical, no stored verdict can change`.
Returning 0 by construction rather than by measurement is the exact failure this whole detector
exists to catch, so it must not be reproduced inside it.

So `reads:` is the comparison subject and it is REQUIRED. The script path is simply its first
member. A site whose `reads:` resolves to nothing at BOTH refs is refused, not scored zero.

## Fields

- `reads:` — space-separated DIST-relative globs: the predicate script AND every schema or data
  file whose content decides a verdict. Materialized at BASE and at THEIRS into a probe root that
  preserves these paths, so the incoming script runs against the incoming schema. Comparison is
  over the whole set; if ANY member moved, the predicate moved.
- `entry:` — which member of `reads:` is the executable, dist-relative.
- `corpus:` — a `find`-style name pattern, resolved under the consumer root.
  **DERIVE IT FROM THE SHIPPED GRAMMAR, NOT BY INVENTION.** The first cut used `*pass[0-9]*` and
  reached 16 series where `core/hooks/ai-dlc-continue.sh:430`'s own live-series glob reaches 119
  on the same tree. A narrow pattern lowers the reported FLOOR without lowering it visibly.
- `series:` — a `sed -E` expression reducing a record path to its SERIES key. A predicate that
  adjudicates single files declares the identity expression.
- `invoke:` — the argument form, `{series}` substituted. This mirrors the form the consumer's
  own gate uses; where they disagree the CONSUMER's is right and this field is stale.
- `verdict:` — a `sed -nE` expression extracting the comparable verdict tokens from the
  predicate's combined stdout+stderr. The compared value is the SORTED SET of what it prints.

## Sites

reads: core/scripts/validate-adversarial-convergence.sh
entry: core/scripts/validate-adversarial-convergence.sh
corpus: *adversarial*p*.md
series: s/(pass|p)[0-9]+\.md$//
invoke: --series {series}
verdict: s/^FAIL \(([A-Z]+) --.*/\1/p

reads: core/scripts/validate-provenance-block.sh core/schemas/provenance-block.json
entry: core/scripts/validate-provenance-block.sh
corpus: *adversarial*p*.md
series: s/$//
invoke: {series}
verdict: s/^FAIL: ([A-Za-z0-9_-]+).*/\1/p
