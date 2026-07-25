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
| V8 | upstream-owned `reconcile/apply.sh` — bare `Phase 3` marker | none; **dropped from scope** |
| V9 | consumer-owned `.claude/hooks/my-own-hook.sh` — same bare marker | 1 (item ref) |

V5 is what makes the fixture able to fail. Without it, an element mutated into
always-rejecting would still look correct: every adversary would be rejected
and the fixture would report success. V6 and V7 exist because a mutation run
showed the original four did not cover element 3's digit-only rule or element
2's CLOSED case — a loosened element 3 and a CLOSED-accepting element 2 both
passed the fixture unchanged.

**V8/V9 are a pair, and neither means anything alone.** They cover the
upstream-owned exemption: Check 16 drops core-manifest paths before the marker
grep, because the four elements are unsatisfiable there (element 1 wants an
`Item N` from the *consumer's* backlog, and `ai-dlc-core-guard.sh` denies the
edit that would add one). Both variants live under `.claude/`, both carry the
same bare `Phase 3` marker, and both satisfy zero elements — only ownership
differs. V8's comment is the verbatim text that failed a real consumer's §6
gate four times at ai-dlc 0.156.0.

Why the pair rather than V8 alone: if the exemption were a blanket `.claude/`
carve-out instead of a core-manifest resolve, V8 would pass **and so would
V9** — a consumer hook smuggling an unaudited stub through the gate. Mutation
runs confirm each fires alone: removing the exemption flips only V8; widening
it to all of `.claude/` flips only V9; deleting `skills/ai-dlc-update/**` from
the seeded manifest flips only V8; hiding `core-paths.sh` makes the driver
exit 2 rather than pass without ever running the filter.

The seed copies the **real** `core-manifest.md` (walking up for whichever
layout it is in) rather than inventing one, so a change to the real manifest's
shape cannot leave this fixture passing against a stale stand-in.

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
