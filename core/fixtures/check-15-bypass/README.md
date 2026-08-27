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
| V12 | a 16-char reason: clears the density floor, under the length floor | 4 (reason) |
| V5 | honest stub — the positive control | none; passes all four |
| V13 | a module docstring reading `Harmonization Phase 4` — prose | none; **not a marker** |
| V16 | `# Phase 2: drain remaining records…` — a section label | none; **not a marker** |
| V14 | `# Phase 1: no live snapshots yet (subgraph not deployed)` | 1 (item ref) |
| V15 | a bare `raise NotImplementedError()` with no prose beside it | 1 (item ref) |
| V8 | upstream-owned `reconcile/apply.sh` — `TODO` marker | none; **dropped from scope** |
| V9 | consumer-owned `.claude/hooks/my-own-hook.sh` — same marker | 1 (item ref) |
| V10 | core fixture `tests/fixtures/check-15-bypass/seed.sh` — `TODO` | none; **dropped from scope** |
| V11 | consumer fixture `tests/fixtures/check-15-bypass-local/seed.sh` — same marker | 1 (item ref) |

V5 is what makes the fixture able to fail. Without it, an element mutated into
always-rejecting would still look correct: every adversary would be rejected
and the fixture would report success. V6 and V7 exist because a mutation run
showed the original four did not cover element 3's digit-only rule or element
2's CLOSED case — a loosened element 3 and a CLOSED-accepting element 2 both
passed the fixture unchanged.

**V4 and V12 are element 4's pair**, and the same mutation run added V12 for
the same reason. Element 4 has two independent floors — a 20-character length
and a ≥10 non-whitespace density — and every earlier variant was under BOTH,
so deleting either left the other catching all of them and the fixture stayed
green with one published floor untestable. V4 is under density only; V12 is
under length only. Each floor now has a mutant that flips exactly one variant.

**V13/V14/V15/V16 are the `Phase N` marker in both directions.** It is the one
alternative in the marker set that is also ordinary English, and as a bare
alternative it was the check's dominant false positive: on the reference
consumer it was the sole matcher on 129 tracked hot-path lines, and all 23
findings in the largest recorded Check 16 failure came from it, every one
suppressed by the operator. A consumer-owned file has no escape hatch — the
only exemption is upstream ownership — so the remediation is rewording true
prose, and a consumer did exactly that, deleting a factual phase reference from
a module docstring to clear a gate. It is now a marker only inside a statement
of absence. V13 is that docstring verbatim and V16 the section-label shape that
accounts for most of the 129; V14 is a real deferral written only as a phase
reference, so deleting the alternative outright rather than narrowing it goes
red; V15 is a marker outside the phase rule, so applying the absence
requirement to the whole set goes red.

V13 and V16 are not redundant, and the difference is which future fix clears
them. A marker gate keyed on comment TEXT — the remedy filed for the sibling
defect, where an identifier named `stub` matches in code — clears V13, which
sits in a docstring carrying no comment prefix, and leaves V16 untouched
because V16 *is* a comment. Only the absence requirement clears V16.

**V8/V9 are a pair, and neither means anything alone.** They cover the
upstream-owned exemption: Check 16 drops core-manifest paths before the marker
grep, because the four elements are unsatisfiable there (element 1 wants an
`Item N` from the *consumer's* backlog, and `ai-dlc-core-guard.sh` denies the
edit that would add one). Both variants live under `.claude/`, both carry the
same `TODO` marker, and both satisfy zero elements — only ownership differs.
V8's block also carries the verbatim text that failed a real consumer's §6 gate
four times at ai-dlc 0.156.0; that text is no longer a marker, which is V13/V16's
rule read a second time in the one file where the false positive was
unclearable. The payload is a `TODO` and not a phase reference on purpose: an
ownership arm seeded on a phase marker reports on the marker vocabulary too, and
narrowing that vocabulary failed this arm alongside its own.

Why the pair rather than V8 alone: if the exemption were a blanket `.claude/`
carve-out instead of a core-manifest resolve, V8 would pass **and so would
V9** — a consumer hook smuggling an unaudited stub through the gate. Mutation
runs confirm each fires alone: removing the exemption flips only V8; widening
it to all of `.claude/` flips only V9; deleting `skills/ai-dlc-update/**` from
the seeded manifest flips only V8; hiding `core-paths.sh` makes the driver
exit 2 rather than pass without ever running the filter.

**V10/V11 are the same pair on fixture ownership**, and they matter because
`tests/fixtures/` is genuinely shared: core ships its adversarial self-tests
there and a consumer's own sit beside them, both using the `check-` prefix, so
the manifest entries are name-exact rather than a glob. V11's directory is
deliberately a core fixture's name plus a suffix — one dropped slash in an entry
(`fixtures/check-15-bypass**`) over-captures it, where a neutrally-named control
would not notice. The stake on V10's side is higher than on V8's: a core
fixture's markers are the payload its own assertions read, so the only way to
clear a Check 16 finding against one is to edit it, which VACATES the fixture.

Mutation runs confirm each fires alone: forcing `core-paths.sh` to answer
not-core for `tests/fixtures/` flips only V10; making its glob loop over-capture
`tests/fixtures/` flips only V11; and the dropped-slash entry flips V11 together
with the guard fixture's consumer-editable assertion and I8's missing-entry
direction — a poor isolator, run once as evidence a malformed entry cannot ship.

The seed copies the **real** `core-manifest.md` (walking up for whichever
layout it is in) rather than inventing one, so a change to the real manifest's
shape cannot leave this fixture passing against a stale stand-in. V10 therefore
goes green only once the real manifest carries `fixtures/check-15-bypass/**`:
the manifest edit and this fixture are atomic by construction.

`run.sh` drives it and asserts the element-per-variant matrix.

**What the driver runs, and what changed.** It used to run a RESTATEMENT.
Check 16 carried `enforcer: []`, so there was no validator to call and `run.sh`
re-implemented the published element regexes inline — proving this fixture's
claim rather than the shipping path's, which its header said outright. The
elements now live in `scripts/ai-dlc/validate-stub-audit.sh` and this driver
calls it, so the code under test and the code that ships are the same bytes.

**Four mutants, because two of the arms are absence-shaped.** V13 and V16 pass
when the validator reports nothing about their file, and a validator that
reported nothing about *any* file would pass them too — a seeded near-miss shows
an arm discriminates between two inputs, not that it discriminates at all. So
each of the three lines the phase rule is spelled on gets a mutant of its own,
run against copies under `mktemp` with `core-paths.sh` copied beside each (the
validator finds its resolver as a sibling, and a copy that cannot resolve one
dies at exit 2, reports nothing, and every absence-shaped arm reads that silence
as a pass). The control runs first and is presence-shaped for that reason.
Restoring the bare alternative flips V13 and V16; deleting the phase marker
flips only V14; widening the absence vocabulary to match anything flips V13 and
V16; dropping `NotImplementedError` from the other markers flips only V15, which
no other arm here notices.

Three assertions are deliberately NOT about the elements, so no element
mutation can flip one: an all-out-of-scope set must exit **4**, not 0
(`EXAMINED NOTHING` — the state every vacuously-green gate check has collapsed
into a pass); a finding must reach the caller as exit **1**; and the run must
report what it LOOKED AT. Both the vacuity and the counts assertions drive the
audited-nothing case through a non-hot-path file rather than an exempt one, so
neither touches the ownership resolve — otherwise a single exemption mutation
flips three assertions and two of them are vacuous.

**What the driver still does not prove.** Check 16 stays `adjudication: llm`.
An adjudicator that ignores the script's verdict is not detected here, and
cannot be from a script.

Run `seed.sh` to reproduce idempotently; `run.sh` to assert.
