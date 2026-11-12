# BL-510 s321 rework-class count

`python3 -I count.py` (stdlib only, exit 0 counted / 2 refused). The consumer repo `/Users/n8/git/graph` is
read only through `git --no-optional-locks -C ... ls-tree|show "<G>:path"` at the pinned sha
`G=ed61de74574b4b1e6649a672373ab49d7eeb9199`; its working tree is never read.

## Population

Every story-level review file under `docs/reviews/s321/` (top level; `shards/`, `*.draft`, `*dev-report*`,
closing writers/reports excluded) whose first verdict is `NEEDS_REWORK`: gate-1 code-review passes and gate-2
QA-validation passes (the QA fail token is `NEEDS_REWORK`). Verdict grammar: `## Verdict: X`, `## Verdict` with the
token on the next non-blank line, or `Verdict: X`; first verdict per file; `Verdict rationale:` is prose.
Tokens present across the kinds: `APPROVED`, `PASS`, `NEEDS_REWORK` only. The file kind filter runs before the
unknown-token refusal. `ff-` (1 pair) and `sr-` (9 pairs) files are outside the population (the s317-s318 baseline
had none; none carries `NEEDS_REWORK`). The two `NEEDS_REWORK` code reviews under
`_bmad-output/implementation-artifacts/s321/` (`base-create-gas`, `base-refunding-router`) are outside the
population and reported separately (that directory also holds two `NEEDS_REWORK` QA reports, listed by the script).
The baseline scope is every story-level `NEEDS_REWORK` under `docs/reviews/<sprint>/` (s317 18 + s318 15 = 33).

## Classes and the mixed rule (stated before labelling)

Definitions are `exp.py` lines 5-6: S = substantive code/test defect, E = evidence/capture/record format,
B = bookkeeping/status/headings. A pass is labelled by its verdict-flipping findings, taken as every finding under that
review's `### Critical` or `### Important` heading (the script re-reads each quoted line and heading at G).
Only S: `S`. S plus any E/B: `SM` (S-mixed; counted in "other", reported separately). Only E: `E`. Only B: `B`.
E plus B and no S: `EB` (counted inside the E+B share, reported separately; CLS had no such case; H1v reads 4 EB rows in s317).

## Controls (all in one run, refusing on mismatch)

Self-probe first (missing label, extra label, unknown token, empty population, no-pass grammar, quote/heading
check, mixed rule, baseline parser); coverage (matched cr/qa/ff/sr files = files carrying a verdict token; refuses before the unknown-token arm); APPROVED+PASS > 0; population 34 = 23 CR + 11 QA;
gate-1 CR distribution `[(1,8),(2,10),(3,4),(4,1),(7,1)]` over 24 stories / 51 passes (`impl_passes.txt`);
baseline parsed from `exp.py` lines 7-26 as text = E 12, B 10, S 10, ? 1, total 33, and joined two ways to the
s317 (18) + s318 (15) derived population.

## Reading

Run output is the record. Verdict-bearing files at G: 107 (the contract's 110 counted differently; the 107 are
all top-level story/ff/sr review files with a verdict). Labelling reading: see the table the script prints;
the labels were produced by the sonnet labeller H1 and are adjudicated against the blind opus relabeller by the owner.
The agreement figures are printed by the script (see Second labelling).

## Second labelling (H1v)

`count.py` also carries the labels of a blind opus labeller, H1v, as a data table (`H1V_TEXT`: sprint, file under
`docs/reviews/<sprint>/`, gate, class, line) for all three sprints (s317 18, s318 15, s321 34 = 67 rows). H1v was given
the review file paths only and picked the verdict-flipping finding itself; one class per file (`S`, `SM`, `E`, `B`,
`EB`, `?`). A `[D]` suffix marks a no-code story whose wrong claim sat in the deliverable document, which H1v read as S.
The primary reading maps `[D]` rows as S (`SM[D]` as SM); the alternate reading maps them to E; both are printed.
**H1v saw reviewers' own `Class:` tags in s321 files, so it is not fully blind there** (1.1 TEST to E, 2.1 BOOKKEEPING
to S[D], 6-1-qa p1 AC1 BOOKKEEPING to S[D], AC2/AC3 BOOKKEEPING to E, 6-1-qa-p2 AC3 BOOKKEEPING to E).

The table is joined two ways (missing and extra both refuse) to the derived population of all three sprints, and its
gate column is checked against the derived gate. Printed: H1v per-class counts and the E+B family (E, B, EB) share per
sprint; binary agreement (E+B family against other, with S, SM and `?` as other) between H1 and H1v on the 34 s321
passes and between H1v and `exp.py` CLS on the 33 baseline passes (out of 33 with CLS `?` counted as other, and out of
32 excluding it), each with the disagreeing keys listed. The self-probe refuses a missing H1v key before the corpus is read.
