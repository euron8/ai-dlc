# Fixture: Check 24 — adversarial cycle convergence

## The bypass this fixture reproduces

v0.46.0 told the adversary that "a clean verdict is a valid outcome, and on a
later pass it is the expected one." It did not give the adversary a **field** to
say so in. `SKILL_INVOCATION_PROVENANCE v1` had no verdict key at all, so the
role invented one per pass — and the invented vocabulary had no success value.

The measured result, on S289's `research-requirements` cycle:

| Pass | CRITICAL | What it stamped |
|---|---|---|
| 1 | 3 | *(no verdict field emitted at all)* |
| 2 | 4 | `exit_condition_met: NO` ← a different key than pass 3 used |
| 3 | 7 | `verdict: EXIT CONDITION NOT MET` |
| 4 | **0** | `verdict: EXIT CONDITION NOT MET` ← **the identical string** |

Pass 4's prose says *"The repair wave converged… I probed the repair hard and it
holds."* Its residue was 0 CRITICAL, 0 MAJOR, 2 MINOR. Under the severity ladder
in `team-roles/adversary.md` — where **MINOR / NIT is the nitpick bucket** — and
the step's exit condition of *"continue until only nitpicks remain,"* the exit
condition **was met**. The adversary refused to say so in the field, because the
field had no word for it. The lead read the prose instead, applied the two
one-line deletions, and passed the §5 planning gate.

**So the gate passed while the last adversarial artifact of record said the exit
condition was not met.** Termination came from the lead overriding the
adversary's own field. Nothing counted a CRITICAL; nothing read a verdict.

Two other defects hid in the same series and are also caught here: CRITICALs rose
3 → 4 → 7 pass-over-pass with no escalation (Rule 8: *divergence is a HARD_BLOCK,
not a reason for another pass*), and two of the four passes were un-adjudicable
because they emitted no `verdict:` key.

## Cases seeded

`seed.sh` builds five throwaway pass-series under a temp dir. `run.sh` asserts
the validator's verdict on each. Exit 0 iff all five are correct.

| Case | Shape | Must |
|---|---|---|
| `converged` | 3 → 1 → 0 CRITICAL, last pass `EXIT_CONDITION_MET` | **PASS** |
| `nitpicks-remain` | last pass 0C/0M but **5 MINOR**, stamps `EXIT_CONDITION_MET` | **PASS** |
| `refused-to-converge` | last pass 0C/0M, stamps `EXIT_CONDITION_NOT_MET` | **FAIL** (B) |
| `divergent` | CRITICALs 3 → 6, no `DIVERGENT_HARD_BLOCK` | **FAIL** (C) |
| `no-verdict` | pass emits no `verdict:` key | **FAIL** (A) |

### The case that decides whether the script is shippable

`nitpicks-remain` is the decoy. A naive implementation reads "the cycle must
converge" as "the last pass must have zero findings" and fails any series with
MINORs left — which would make the exit condition *"continue until only nitpicks
remain"* unreachable all over again, in a new place. That is the v0.46.0 bug
reintroduced one layer down. The validator must PASS a clean-but-nitpicky
terminal pass, and the only thing separating it from `refused-to-converge` is the
verdict the adversary stamped. That is the whole point: **the residue decides
whether the verdict is honest; the verdict decides whether the gate opens.**

## v0.103.0 — arm H, the repair-record differential

A converging series proves findings **fell**, which proves a repair happened between
those passes. `carry-over-evaluation.md` §3a fences that repair to a `remediator`
subagent (*"the lead does not repair the artifact itself"*) delivered as a repair record
the next pass verifies against. Arm H asserts the record exists and is structured — and
the two cases that prove it is real are a **differential**:

| Case | Shape | Must |
|---|---|---|
| `repaired-delegated` | 2C/1M → 0C/1M → 0C/0M MET, **with** `s1-brief-repair-p1/p2.md` | **PASS** |
| `repaired-inline-no-record` | the SAME series, **no** repair records | **FAIL** (H) |
| `repair-record-empty` | same series, p1's record is narrative prose, not structured | **FAIL** (H) |

`repaired-delegated` and `repaired-inline-no-record` carry **byte-identical pass series**;
the only difference on disk is the two repair records. A validator that reads the series
instead of statting the record cannot separate them — neutralize arm H and
`repaired-inline-no-record` flips to exit 0, which is the mutation proof baked into the
pair. This is the S295 defect: a lead that repairs inline leaves a series indistinguishable
from a delegated one, and arms A–G pass over it.

## v0.355.0 — the field reader, pinned from both sides, and joined to what is taught

The three cases above all seeded the field headings **plain** — `- disposition:` — which is
the form `remediator.md` teaches and the form arm H read. So the fixture was green over its
own blind spot for nine releases: markdown puts emphasis on a field name, the reference
consumer wrote `- **disposition:**` in **413 of 977** field lines, and the bracket class
`[[:space:]-]` does not contain `*`. **37 of that consumer's 74 repair records read
UNSTRUCTURED, and 35 of the 37 carry all three fields in plain sight.** Arm H fired on 10 of
its 46 live series; it was a false positive against the house style on 5 of them.

A fixture seeded from what its reader accepts asserts nothing about what its reader rejects.
Three cases now hold the reader between two walls it cannot pass through at once:

| Case | Shape | Must |
|---|---|---|
| `repaired-delegated-bold` | the SAME series again, records in the house style `- **disposition:**` | **PASS** |
| `repair-record-off-label` | emphasis is fine, but `- **edit sites:**`, `- derivation (qualifier):`, `### Derivation 1 —` | **FAIL** (H) |
| `H-BIND` | runs the validator's own `repair_field` on `remediator.md`'s own template lines | **PASS** |

Narrow the reader back and `repaired-delegated-bold` goes red. Widen it to any line
mentioning the word and `repair-record-off-label` does. **Neither can move alone**, which is
the whole guarantee: the anchor is what keeps arm H able to fire, not the tightness of the
class, and an arm H that cannot fire reads exactly like one that passed.

`H-BIND` is the third side. The two cases above prove the reader accepts the bold form; they
do not prove that form is the one `remediator.md` TEACHES — and for nine releases it was not.
So `H-BIND` **evals the one-line `repair_field` definition out of the validator** and applies
it to the three field lines it extracts from the template, plus their bold and italic twins.
It runs that code rather than a copy: a restated regex could be wrong in the fixture and right
in the validator, and the join would report clean. Its controls — prose, an absent file, and
the renamed fields — are what stop a `repair_field` that returns 0 unconditionally from
passing every other assertion. A fourth arm joins `gate-validation.md`, which states the same
three labels to the lead.

**A zero here is not a finding.** If the definition were renamed, or the template reworded,
every assertion would pass over an empty set and report clean — so the extraction counts are
guarded (`want 1` definition, `want 3` template lines) and a miss says `FIXTURE BROKEN`. That
guard fired on this arm's first run: the draft used `\|` alternation, which is a GNU sed
extension and matches nothing under BSD sed, and it extracted 0 lines.

Mutation-tested on four full-tree copies, `cmp -s` guarded, against an unmutated control that
passes 80 of 80:

| Mutant | Kills |
|---|---|
| reader narrowed to the 0.354.0 class | `repaired-delegated-bold`, `H-BIND` grammar (2) |
| `remediator.md` relabels one template field | `H-BIND` extraction guard only (1) |
| `repair_field` returns 0 unconditionally | `repair-record-empty`, `repair-record-off-label`, both messages, `H-BIND` controls (5) |
| `gate-validation.md` drops the `derivation:` label | `H-BIND` teaching arm only (1) |

The control must be a **full-tree** copy. A partial one — the four files this arm reads,
copied into a skeleton — fails 8 unrelated assertions because the other arms cannot resolve
their own dependencies, and 8 pre-existing failures score as kills.

## The `skill:` field in the seeded blocks is INERT — do not read it as coverage

v0.58.0 changed the seeded blocks to `skill: ai-dlc-adversary-review`, because that is
what a real convergence pass now stamps. **This fixture does not test that, and cannot.**
`validate-adversarial-convergence.sh` never reads `skill:` — it reads `verdict`,
`findings_*`, and the pass number in the *filename*, and nothing else. Change the value to
anything at all and this fixture stays green.

That is a property worth stating rather than leaving to be rediscovered: Check 24 is
name-blind, so the v0.58.0 identifier change could not break it, and no assertion here
would have caught it if it could. The enum and the solo rung are `check-17-bypass`'s job
(V6/V7/V8). Keeping the value current keeps the corpus honest; it does not make it a test.

## Removal condition

Retire when the adversary's report template is GENERATED from the severity ladder
rather than hand-stamped per pass, so the verdict cannot disagree with the
residue it sits next to.
