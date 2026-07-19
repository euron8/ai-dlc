# Check 16 (Stub Audit) Bypass Fixture

Historical name: check-15-bypass (fixture dir keeps historical name per
LR-S155-3 wording; the renumbered check is Check 16).

Adversarial variants — each satisfies every element of Check 16 except one,
so the driver can assert *which* element rejects it:

| Variant | Bypass | Fails element |
|---|---|---|
| V1 | fictional `Item 999`, absent from the backlog | 2 (item OPEN/IN SPRINT) |
| V2 | `deferral-reason: TBD`, under the length floor | 4 (reason) |
| V3 | no `file:line` reference at all | 3 (file:line) |
| V4 | padding-only reason — clears the 19+ length rule, fails density | 4 (reason) |
| V6 | `src/pool.py:FIXME` — a file ref with no digits after the colon | 3 (file:line) |
| V7 | cites `Item 7`, which is CLOSED | 2 (item OPEN/IN SPRINT) |
| V5 | honest stub — the positive control | none; passes all four |

V5 is what makes the fixture able to fail. Without it, an element mutated into
always-rejecting would still look correct: every adversary would be rejected
and the fixture would report success. V6 and V7 exist because a mutation run
showed the original four did not cover element 3's digit-only rule or element
2's CLOSED case — a loosened element 3 and a CLOSED-accepting element 2 both
passed the fixture unchanged.

`run.sh` drives it and asserts the element-per-variant matrix.

**What the driver does not prove.** Check 16 is `adjudication: llm` with
`enforcer: []` — no validator script exists to call, unlike `check-17-bypass`,
whose driver invokes the real `validate-provenance-block.sh`. So `run.sh`
evaluates the check's own published element regexes against the seed. That
tests this fixture's claim — the seeded stubs really do exhibit the bypasses,
and the published elements catch them — not the adjudicator's behaviour. An
LLM that ignores the published elements is not detected here, and cannot be
from a script.

Run `seed.sh` to reproduce idempotently; `run.sh` to assert.
