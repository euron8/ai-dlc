# Push-candidate adjudication — graph ledger, 2026-07-19

Every entry in the graph consumer's `_bmad-output/ai-dlc-update/push-candidate-ledger.md`
was ground-truthed against ai-dlc HEAD (v0.95.0 at the time of review). The consumer's
conclusions were treated as hypotheses, not findings.

Three landed as v0.96.0–v0.98.0. Two are real but deferred. Two are rejected. Four are
dead and should be drained from the ledger. One new defect was found while proving the
first fix, and one ledger claim was **understated** rather than overstated.

This document is the upstream half. The consumer owns its own ledger; nothing here edits
the graph repo.

## Landed

| Version | Entry | Note |
|---|---|---|
| 0.96.0 | `check-17-counts/run.sh` cannot locate the validator | worse than reported — see below |
| 0.97.0 | `setup-sites.md` omits the escalated-reviewer model sites | plus I22 to close the class |
| 0.98.0 | `apply.sh:234` reads VERSION from the working tree | plus a fixture to hold it |

Two of the three shipped with a mechanism rather than only a patch, because in both cases
the instance had already recurred: the model-site omission is the second occurrence, and
the stamp fix is a single line nothing would have held.

### Where the consumer undercounted

The `setup-sites.md` entry calls the `adversary.md` precedent a "nine-version manifest
gap." The history says seventeen: `adversary.md` carried a `{*_model_*}` token from
**v0.30.0** (`3727f68`) and was not declared a site until **v0.47.0** (`e86cd9e`), whose
own commit title is *"the reconcile blanked the config it exists to preserve."* So that
precedent is not a near-miss — it is the same bug having already caused the data loss
once. The class is worse than the ledger claims, not better.

## New defect, found while proving 0.96.0

The 0.96.0 proof required running the whole fixture suite from a real consumer install
rather than the distribution tree. That surfaced a second fixture with the same
"cannot run on a consumer" shape, which no ledger entry mentions:

**`gate-adjudication/seed.sh:25` reads `.claude/skills/ai-dlc/enforcement-map.yaml`, which
`install.sh` never writes.** The doc loop at `install.sh:170` ships `escalations.md`,
`rule-authoring.md`, and `core-manifest.md`, but not `enforcement-map.yaml`. On a fresh
install the fixture aborts with exit 2.

It is masked on the graph consumer, which *does* have the file — acquired through some
path other than `install.sh`, since the file is listed in neither `core-manifest.md` nor
`setup-sites.md`'s `core_manifest` block. That is why the consumer never saw this and why
it is absent from the ledger.

**Not fixed here, deliberately.** Whether `enforcement-map.yaml` should exist on a
consumer at all is a design question — it is not currently a declared core file — and the
answer picks between three different fixes (ship it in the doc loop; mark the fixture
`.dist-only`; have the seed skip gracefully). That is a decision, not a patch, so it is
filed rather than guessed at.

## Deferred — real, but not mechanical

**Provenance placeholder-literal rejection.** Confirmed: the schema pattern
`^toolu_[A-Za-z0-9_-]{6,}$` matches the literal `toolu_PLACEHOLDER`, so a placeholder id
passes the reader. Deferred because the fix is a policy call — blocklist known literals,
or tighten the charset — and it touches the single-source JSON engine that v0.60.0 exists
to keep single. Worth doing; wants its own decision.

**`layer-drift.sh` EXTENSION-RESTATES-CORE matches on heading, not body.** Confirmed as
described; the script's own comments at lines 371–373 state the number+title matching
rule outright. But the remedy the consumer proposes — body-overlap comparison, or a
declared `adds-to:` grain for extensions — is a redesign of the drift detector, not a
patch, and it changes what every consumer's next pull reports. Wants a spec.

## Rejected

**Decision-branch execution-coverage for `sprint-review` §3.** Core now carries
"Core-path seam non-deferral" (`steps/sprint-review.md:101-121`), which covers the
pre-merge wiring case with a mutation-RED requirement. The residual delta is a decision
branch un-exercised by *live organic traffic* on a *size-unbounded live-capital path* —
graph's domain vocabulary. Shipping it to every consumer of the distribution is the
role-file context-hygiene problem. If a generalizable rule is in there, it needs
re-authoring in domain-neutral terms as its own proposal.

**`scan-stray-provenance.sh` GENERATED-region carve-out.** No such script exists in core.
This is a request to adopt a consumer-only script, not a report of a core defect, and it
should be evaluated as a new feature on its own merits rather than absorbed in a defect
batch.

## Dead — recommend draining from the ledger

| Entry | Status |
|---|---|
| Invariant 3 hardcodes the `uni` set | **Falsified.** No `const uni=` in `steps/retro.md`. `2a`, `25`, `26` are in the GATE_MANIFEST `universal` row (`gate-validation.md:62`), so the orphan report that motivated it cannot recur as described. |
| Rule 29 ack hook fires against `ai-dlc-update` | **Absorbed.** `hooks/ai-dlc-acknowledge.sh:296` carves out `_bmad-output/ai-dlc-update/*`, and the surrounding comment gives the same reasoning the ledger asked for. |
| `HANDOFF_GUARD` Check 0 | **Absorbed.** `hooks/ai-dlc-continue.sh:167,201`. |
| `tea.md` consumer-only role | **Absorbed.** `core/team-roles/tea.md`. |

## The `push_candidate: true` block — recheck, do not push

The ledger's own header says the count is stale and to "treat every line here as a lead
to verify, not as evidence." That is the right instruction and it should be followed
before any future push-mine: in the previous batch, 7 of the last 8 catalog items turned
out to have expired premises, and 4 of the 15 entries reviewed today were already dead.

The pattern is consistent enough to plan around — entries rot faster than they are
drained, so a premise recheck is cheaper than an absorption pass, and it is where a
push-mine should start rather than end.
