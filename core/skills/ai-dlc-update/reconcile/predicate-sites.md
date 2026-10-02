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

`core/scripts/validate-provenance-block.sh` says so in its own header — *"THE SCHEMA IS NOT IN
THIS FILE"* — and resolves `.claude/schemas/provenance-block.json` at runtime. (That is the CONSUMER path, which is the one a reader of this file needs: `install.sh`
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
- `corpus-root:` — OPTIONAL, consumer-relative directory the `corpus:` pattern is searched under.
  Defaults to `_bmad-output`. A site whose stored subject lives elsewhere declares it here;
  without it that subject is unreachable and the site reads UNDECIDABLE on every consumer. A
  value with a `..` component, a leading `/` or any whitespace is refused, and the site reports
  UNDECIDABLE naming the field.
- `corpus:` — a `find`-style name pattern, resolved under `<consumer>/<corpus-root>`.
  **DERIVE IT FROM THE SHIPPED GRAMMAR, NOT BY INVENTION.** The first cut used `*pass[0-9]*` and
  reached 16 series where the live-series glob between `core/hooks/ai-dlc-continue.sh`'s
  `I81 LIVE-SERIES BLOCK` markers reaches 119
  on the same tree. A narrow pattern lowers the reported FLOOR without lowering it visibly.
- `series:` — a `sed -E` expression reducing a record path to its SERIES key. A predicate that
  adjudicates single files declares the identity expression.
- `invoke:` — the argument form, `{series}` substituted. This mirrors the form the consumer's
  own gate uses; where they disagree the CONSUMER's is right and this field is stale.
- `verdict:` — a `sed -nE` expression extracting the comparable verdict tokens from the
  predicate's combined stdout+stderr. The compared value is the SORTED SET of what it prints.
- `pass:` — OPTIONAL `sed -nE` expression matching the line the predicate prints when it
  PASSES, copied from the validator's own emitter. It lets the row split a series that yielded
  no verdict token into `passed` (pass line on both sides) and `unclassified` (neither). A site
  without it prints `unclassified=n/a (grammar spells failures only)`, because its tokenless
  series are passes and unparseable outputs mixed. The value `in-verdict` declares that
  `verdict:` already extracts the pass verdict as a token (`PASS`, `OK`, a verdict class), so a
  pass is counted in `compared` and every tokenless series is unclassified. Never write a pass
  line the validator does not print.

## Each side runs rooted at its own probe root, so consumer DATA must be passed in

`predicate-differential.sh` runs each side with `AI_DLC_PROJECT_ROOT` set to that side's probe
root and the cwd at the consumer. Without the pin, a predicate resolving its schema under its
project root fell through to the consumer's INSTALLED `.claude/schemas/` on both sides — the
probe root carries no walk-up marker, and the cwd, `CLAUDE_PROJECT_DIR` and any inherited
`AI_DLC_PROJECT_ROOT` all name the consumer — so a schema-only change compared one schema with
itself. A walk-up marker alone is not the fix: an inherited `AI_DLC_PROJECT_ROOT` beats the walk.

The cost of the pin is that consumer data a predicate looks up under its root is no longer found
there. Every such input is therefore passed explicitly:

- the known-skills extension is passed as `AI_DLC_KNOWN_SKILLS_EXT`, resolved once from the
  consumer's `.claude/skills/ai-dlc/extensions/known-skills.json`. Searched under the probe root
  it resolves to nothing on BOTH sides, an identical empty input that parses as agreement.
  **This makes a change to the validator's extension SEARCH PATH unobservable to the
  differential**: both sides are handed the file by path, so a release that moves where the
  validator looks for it compares identically. Only a change to how the file's CONTENT is read
  is still seen.
- `validate-gate-adjudication.sh` resolves its schema, `enforcement-map.yaml` and its
  `validate-adversarial-convergence.sh` sibling under the pinned root, which is why all three
  are in `reads:`. Drop one and that side has no copy of it. `--series` is the form the
  consumer's own gate runs; the per-pass form needs a gate type per file, which the `invoke:`
  grammar cannot derive. Its escalations default (`$GA_MAP_ROOT/docs/escalations/pending.md`)
  is read only in its adjudicate mode, which no site invokes.
- `validate-snapshot-conservation.sh` gets `--root .` and `validate-suppression-lifetime.sh`
  gets an explicit `--gate-metrics`. Without them, a predicate that cannot find its inputs reports
  NOT-APPLICABLE or an uncounted lifetime on both sides, and that parses as agreement.

The verdict grammars extract the verdict CLASS and the subject each finding names, never a
count. `catalog=57` against `catalog=58` is the catalog growing, not a stored artifact being
reclassified.

**The suppression-lifetime site declares `corpus-root: docs/escalations`.** Its subject is
`docs/escalations/pending.md`, outside `_bmad-output/`. Before the field existed the reader
searched only `_bmad-output/` and the site reported UNDECIDABLE whenever its read-set moved.

Every row past the manifest carries `population: root=… corpus=… series=…`, each value
backticked. Every row whose corpus was read also carries `records= series= compared=` and either
`passed= unclassified=` (a site with `pass:`) or `unclassified=n/a (grammar spells failures
only)`. The population is static; the counts come from a live corpus, so `emit-report.sh`
carries only the population into the byte-compared report region and the counts stay in the
detector's own rows.

## Sites

reads: core/scripts/validate-adversarial-convergence.sh
entry: core/scripts/validate-adversarial-convergence.sh
corpus: *adversarial*p*.md
series: s/(pass|p)[0-9]+\.md$//
invoke: --series {series}
pass: s/^PASS: the cycle converged.*/PASS/p
verdict: s/^FAIL \(([A-Z0-9]+) --.*/\1/p

reads: core/scripts/validate-provenance-block.sh core/schemas/provenance-block.json
entry: core/scripts/validate-provenance-block.sh
corpus: *adversarial*p*.md
series: s/$//
invoke: {series}
pass: s/^VALIDATE-PROVENANCE-BLOCK: PASS .*/PASS/p
verdict: s/^FAIL: ([A-Za-z0-9_-]+).*/\1/p

reads: core/scripts/validate-gate-adjudication.sh core/schemas/gate-adjudication-verdict.json core/skills/ai-dlc/enforcement-map.yaml core/scripts/validate-adversarial-convergence.sh
entry: core/scripts/validate-gate-adjudication.sh
corpus: *.verdict.json
series: s|/[^/]*\.verdict\.json$||
invoke: --series {series}
pass: in-verdict
verdict: s/^VALIDATE-GATE-ADJUDICATION: (PASS|FAIL).*/\1/p; s/^  - STALLED: series '([^']+)'.* check '([^']+)' has held FAIL.*/STALLED \1 \2/p; s/^  - (MISSING|UNSTRUCTURED) REPAIR RECORD: series '([^']+)' \([^)]*\) pass ([0-9]+).*/\1 REPAIR RECORD \2 p\3/p; s/^  - SPLIT SERIES: check '([^']+)'.* between series '([^']+)'.*/SPLIT SERIES \2 \1/p; s/^  - series '([^']+)' (has two passes|spans gate_types).*/\2 \1/p; s/^  - ([^ ]+): (gate_nonce|carries no gate_series_id).*/\2 \1/p

reads: core/scripts/validate-snapshot-conservation.sh
entry: core/scripts/validate-snapshot-conservation.sh
corpus: pipeline-snapshot.md
series: s/$//
invoke: --root . --snapshot {series}
pass: in-verdict
verdict: s/^verdict[[:space:]]+: ([A-Z-]+).*/\1/p; s/^(FAIL|WARN): .*/\1/p

reads: core/scripts/validate-suppression-lifetime.sh core/skills/ai-dlc/enforcement-map.yaml
entry: core/scripts/validate-suppression-lifetime.sh
corpus-root: docs/escalations
corpus: pending.md
series: s/$//
invoke: --escalations {series} --gate-metrics _bmad-output/implementation-artifacts/gate-metrics.jsonl
pass: in-verdict
verdict: s/^OK: EXAMINED NOTHING.*/EXAMINED-NOTHING/p; s/^OK: .*/OK/p; s/^FAIL: suppression of check '([^']+)' is past its lifetime.*/EXPIRED \1/p; s/^FAIL: a ([A-Z_]+) entry names check\(s\) *(.*), which are recorded FAILING.*/TERMINAL \1 \2/p; s/^FAIL: malformed SUPPRESSED entry -- missing:(.*)/MALFORMED\1/p; s/^FAIL: \*\*Suppresses:\*\* names '([^']+)'.*/UNKNOWN-CHECK \1/p; s/^FAIL: \*\*Expires after:\*\* ([^ ]+) gates is outside.*/EXPIRY-RANGE \1/p; s/^FAIL: suppression fields on an entry that does not classify.*/FIELDS-ON-NON-SUPPRESSED/p; s/^FAIL: baselined key no longer reproduces: (.*)/STALE-BASELINE \1/p
