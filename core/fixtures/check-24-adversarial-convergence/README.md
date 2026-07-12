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

## Removal condition

Retire when the adversary's report template is GENERATED from the severity ladder
rather than hand-stamped per pass, so the verdict cannot disagree with the
residue it sits next to.
