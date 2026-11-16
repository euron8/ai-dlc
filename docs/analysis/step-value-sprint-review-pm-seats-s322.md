# Step value — the sprint-review pm seats, s322 (BL-1004's second reading)

BL-1004 recorded one sprint's reading: on graph s321 the sprint-review pm seats cost $17.00 and made 0 of the
step's 15 step-unique survivors (`step-value-sprint-review-deploy-validate-s321.md`). Its decision waited on "the
same reading on the next measured graph sprint, by the same method and script". This is that reading, on s322, by
the s321 reading's method. Graph is read only: every graph read is `git show`, `git ls-tree`, `git diff` or
`git grep` of committed objects. `step-value-b257/bl1004/pm_seats_s322.py` produces every count and dollar figure
below, beside `sr_dv_yield.py`, which is pinned to s319 and s321 and stays unchanged. The per-finding classes are
manual readings and are listed in full for the pm seats' findings.

Refs (graph): `95d831207` (the sprint-review party briefs: the tree the round read), `39aa9db6f` (the sprint
branch at the sprint-review gate PASS, holding the seat files, the triage and every fix), `e0ebaf019` (the Sprint
322 squash on `main`, #1317: the shipped artifact).

## Method, as applied

Population: every `## F-n (major)` or `(critical)` heading in a sprint-review seat file
(`_bmad-output/party-mode/s322/sprint-review-<role>-<n|cross>.md`, 45 files: 8 per-story seats and one cross seat
for each of architect, dev, pm, qa and tea). The script counts 45 major, 0 critical and 112 minor, which MATCHes the
triage file's own header ("45 major, 112 minor, 0 critical"). The sprint-level adversary one-shot
(`feed79995`, "2 Suggestions, 0 Critical/Important") adds no C/M finding. The triage
(`implementation-artifacts/s322/sprint-review-party-triage.md`) merges the 157 findings into 69 entries, 26 of
them major, each with a `sources:` line naming the seat findings it merges. Its entry ids (T-n) are used as the
defect ids here.

The classes are the s321 reading's, first that applies: REFOUND (another seat of the round, or an earlier step,
raised the same defect; an earlier raise whose closure did not reach the artifact is REFOUND (open)),
REPAIR-INTRODUCED, UNIQUE-SURVIVED (the fix commit the commit body names, with its added lines present at the
squash), ACCEPTED (filed as a carry-over or a note, no fix), UNIQUE-unverified. As in s321, a defect several seats
raised is one defect at the per-step level, and it is credited to every seat that raised it.

Earlier raises were searched over `docs/reviews/s322`, `implementation-artifacts/s322` and
`planning-artifacts/s322` at `95d831207`, the round's own briefs excluded: one token per defect (script block 5),
then a read of the hits. The positive control is T-4, which story 1.4 had raised before the round: its dev report
says "`$DEPLOY_RANGE` is named at both sites, never defined", and its gate-transition plans carry "Both call sites
pass a `$DEPLOY_RANGE` that nothing defines or exports". The impossible token reads 0.

## Cost (labels `sprint-review` + `gate-validation[sprint-review]`)

One extraction, `EXTRACT_WIN_END=2026-11-12T09:38:14Z` (`extract.py`, `spawns.py`, `analyze.py`): token control
24564297029 on both sides, 0 subagents unjoined. The s321 control in the same run reproduces the s321 reading
and BL-1004: pm 26 spawns, $17.00, 0.75 agent-h; step 169 spawns, $209.09 (MATCH).

| s322 phase | Spawns | $ | Agent-h |
|---|---|---|---|
| party seats, per-story | 40 | $47.24 | 1.70 |
| party seats, cross | 5 | $13.51 | 0.54 |
| consolidation, triage, round dispatcher | 2 | $5.84 | 0.45 |
| adversary one-shot | 1 | $2.84 | 0.14 |
| fixes, with their review and QA | 9 | $7.51 | 0.88 |
| gate adjudicators | 8 | $5.13 | 0.32 |
| **total** | **65** | **$82.08** | **4.04** |

Seats by (role, model ran): architect opus 9 $23.26, tea opus 9 $20.91, **pm sonnet 9 $6.51** (0.23 agent-h),
dev sonnet 9 $5.05, qa sonnet 9 $5.04. The label `sprint-review` alone is 57 spawns, $76.95; the other 8 are the
gate adjudicators (BL-1003's split).

## The pm seats' findings (9 C/M)

| Entry | pm finding | Defect | Other roles' seats on the entry | Earlier raise | Fix, added lines at ship | Unique survivor | Consequence |
|---|---|---|---|---|---|---|---|
| T-1 pm-1::F-1, pm-cross::F-1 | 2 | 1.1 AC4 marker has no named owner and no lawful PR route to `main` before the roll; the briefed deadline (15 Nov) is the wrong one (AC7 binds the roll) | architect-1::F-1 (major); qa-1::F-1, qa-cross::F-5 (minor) | none: 1.1 and its QA state the deferral and its predicate, not the missing route | `95a8f1ba2`, 100% | yes, shared with architect | medium: the deploy-validate ordering, executed through the named route (#1318) |
| T-2 pm-1::F-3, pm-cross::F-2 | 2 | 1.1 AC5's 13-leaf `layers` gap is carried in no durable operator-facing record, so Epic 5 cannot close from the sprint's own evidence | dev-1::F-2, qa-cross::F-6, qa-1::F-2 (all minor) | none: the gap is named in 1.1 and its QA, with no escalation asked | `b2f0cbc41` 100%, `95a8f1ba2` 100% | yes, the only major raises are pm's | medium: an operator decision with no route |
| T-4 pm-4::F-1 | 1 | the D-4 `DEPLOY_RANGE` export has no producer: Check 926 FAILs every `rebalancer/**` deploy | architect-4::F-1, architect-cross::F-3, qa-4::F-3, tea-4::F-1 (major); dev-4::F-2 (minor) | REFOUND (open): story 1.4's dev report and gate-transition plans carried it | `e946cb60b`, 100% | no (REFOUND open) | high (a HARD_BLOCK on the sprint's own deploy), not step-unique |
| T-11 pm-3::F-1 | 1 | the deploy-validate full smoke gate is not insulated from the `networkidle` defect 1.3 fixed for its own tests | dev-3::F-3 (minor) | the defect itself is a carry-over (CO-S322-LIVE-SMOKE-REBALANCER-PAGE-LOADERS-NETWORKIDLE) | none: accepted as a preconditions note, the fix left to the carry-over | no (ACCEPTED) | medium |
| T-12 pm-4::F-2 | 1 | 1.4 AC8(a), the lead's recorded diff review of the two protected rule files before merge, is absent and on no pre-merge list | qa-4::F-5 (minor) | none: QA restates the deferral; the test-strategy rounds considered "the AC8(a) record with no named file" and did not raise it | the snapshot's single precondition list, item (1), present at `39aa9db6f` and at ship, absent at `95d831207` | yes, the only major raise is pm's | medium: a pre-merge review of protected rule files |
| T-13 pm-5::F-1 | 1 | 1.5 frontmatter `deferred_acs` lists AC8 only while its body and the sprint list defer AC1 too | tea-5::F-1 (major); architect-5::F-1, qa-cross::F-3, architect-cross::F-5 (minor) | none found | `28388fb70` 100%, `fcca51cad` 97.9% | yes, shared with tea | low: record consistency |
| T-14 pm-cross::F-3 | 1 | the sprint's deploy preconditions are scattered over five stories and the briefed list omits five of them | qa-2::F-2 (minor); pm-2::F-1 (minor) | none: "deploy precondition" hits before the round are carry-over-evaluation records about other items | the snapshot's single ordered precondition list ("consolidated at sprint review T-14"), at `39aa9db6f` and at ship | yes, the only major raise is pm's | medium: the deploy's own ordered checklist |

Every pm finding sits in an entry that another role's seat also raised, at major or at minor, so none is the pm
seats' alone. In three of the five survivors (T-2, T-12, T-14) every major source is a pm seat's and the other
roles raised the defect at minor only; all three concern the sprint's deferred acceptance criteria and deploy
preconditions read across stories.

## Reading under the decision rule

BL-1004's rule: remove the pm seats if s322 also reads 0 step-unique survivors from them and no high-consequence
catch is theirs alone; keep them if they make at least one step-unique survivor at a cost per survivor no higher
than the step's own.

- The pm seats made **5** step-unique survivors (T-1, T-2, T-12, T-13, T-14) for **$6.51 and 0.23 agent-h**:
  **$1.30 per survivor**.
- The step's own cost per survivor is at least **$3.16** ($82.08 over at most 26 survivors, the triage's 26 distinct
  major entries; $2.96 on the label `sprint-review` alone). The bound needs no classification of the other roles'
  entries: pm would need only 3 survivors to sit at or below it (script block 6).
- **KEEP.** The second reading does not repeat s321's zero, so the remove branch does not apply, and the keep branch
  holds with a margin of more than two to one. The high-consequence guard is not reached: no pm survivor is high
  consequence, and the one high-consequence pm raise (T-4) was REFOUND (open).

What this reading does not measure: whether the other roles, at minor, would have carried T-2, T-12 and T-14 to a
fix without the pm raise. The triage graded each entry by its sources, and in all three the only major sources are
the pm seats'.

## Commands

```
G=/Users/n8/git/graph   # read only; every read is git show / ls-tree / diff / grep of committed objects
OUT=$(mktemp -d); export EXTRACT_WIN_END=2026-11-12T09:38:14Z
A=docs/analysis/pipeline-efficiency-s317-s318/scripts; B=docs/analysis/pipeline-efficiency-s317-s320/scripts
python3 -I $B/extract.py $OUT && python3 -I $A/spawns.py $OUT && python3 -I $A/analyze.py $OUT
python3 -I docs/analysis/step-value-b257/bl1004/pm_seats_s322.py $OUT $G
python3 -I $B/roll.py $OUT --seats     # the per-story figures on BL-1004's Outcome line
```

The script's output is `step-value-b257/bl1004/out.txt`; the roll.py group rows are in
`step-value-b257/bl1004/out.roll-sprint-review.txt`.
