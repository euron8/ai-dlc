# Check 1c Bypass Fixture

Two branches are seeded into a real git repo.

**`bypass` — the adversary.** A commit subject carrying the literal word
`research` in unrelated prose (`Sprint 42 fix: research findings about noop`),
which a naive substring grep matches and arm (a)'s anchored regex does not.
Its PRD *does* carry a `Research Findings` heading — so a naive
section-presence check passes — but its markers are `R1:` with a colon, which
a loose `R[0-9]+` matches and arm (b)'s anchored dash-delimited marker regex
does not. Neither arm matches: Check 1c must FAIL this branch.

**`honest` — the positive control.** A real research commit subject and a PRD
with real `**R1 — ...**` markers. Both anchored arms match: Check 1c must PASS
this branch.

The control is what makes the fixture able to fail. Without it, an arm regex
mutated to match nothing at all would still look correct — the adversary would
be rejected for the wrong reason and the fixture would report success.

`run.sh` drives it and asserts the eight-way match matrix (anchored vs naive,
per arm, per branch).

**What the driver does not prove.** Check 1c is `adjudication: llm` with
`enforcer: []` — no validator script exists to call, unlike `check-17-bypass`,
whose driver invokes the real `validate-provenance-block.sh`. So `run.sh`
evaluates the check's own published arm regexes against the seed. That tests
this fixture's claim — the seeded branch really is a bypass, and the anchored
forms catch what the naive forms miss — not the adjudicator's behaviour. An
LLM that ignores the published regexes is not detected here, and cannot be
from a script.

Run `seed.sh` to reproduce idempotently; `run.sh` to assert.
