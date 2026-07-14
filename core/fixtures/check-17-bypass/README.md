# Check 17 (Skill-Invocation Provenance) Bypass Fixture

Five variants of a forged or broken `SKILL_INVOCATION_PROVENANCE v1` block.

| Variant | File | Defect | `validate-provenance-block.sh` | `validate-retro-evidence.sh` |
|---|---|---|---|---|
| V1 | `sprint-901.md` | no provenance block at all | FAIL | — |
| V2 | `sprint-902.md` | `tool_use_id` stripped | FAIL | — |
| V3 | `sprint-903.md` | `skill:` names an unknown skill | FAIL | — |
| V4 | `sprint-904.md` | `transcript_path` missing `@<sha>` | FAIL | — |
| V5 | `sprint-905.md` | well-formed block, **fabricated SHA** | **PASS** | **FAIL** |
| V6 | `s999-brief-adversarial-p2.md` | native convergence review, `mode: solo` | FAIL *(on the solo rung)* | — |
| V7 | `s999-brief-adversarial-p3.md` | native convergence review, `mode: subagent` | **PASS** | — |
| V8 | `s999-brief-adversarial-p4.md` | `mode: solo` with **no `skill:` field** | FAIL *(on the solo rung)* | — |
| V9 | `s999-story-1.md` | native story + a consumer's **retired `--require-skill` pin** | FAIL *(naming the retired pin)* | — |

**V6/V7/V8 (v0.58.0) assert on the MESSAGE, not the exit code — and that is the whole
design.** The Rule 8 convergence cycle no longer invokes a Skill; it dispatches the
`adversary` role and stamps `skill: ai-dlc-adversary-review`. A naive fixture ("a solo
native block must exit non-zero") would pass whether or not the change is correct: with
the name absent from `KNOWN_SKILLS` the block fails as an *unknown skill*, and with it
present it fails on the *Rule 20 solo rung*. Same exit status, opposite meanings, and
only one of them is Check 17 doing its job.

So the three pin the three distinct properties:
- **V7** — the enum accepts the native review. Drop `ai-dlc-adversary-review` from
  `KNOWN_SKILLS` and every real convergence pass becomes un-gateable. V7 goes red.
- **V6** — a solo convergence review is caught *as solo*, not incidentally.
- **V8** — `mode: solo` is rejected on its own terms, with no `skill:` field to be
  recognised by. This is the only witness that the solo rung is **not** gated on enum
  membership. Restore the old `if fields.get("skill") in KNOWN_SKILLS and ...` guard and
  V8 alone goes red — the other seven stay green, which is exactly how that guard stayed
  invisible for so long. It was vacuous, so it looked free; what it actually did was make
  the solo rung unreachable for any block outside the enum, including one with no `skill:`
  at all. "Drop the field, it names no skill" is the obvious way to model a role dispatch,
  and it would have silently disarmed Check 17's only teeth.
- **V9** — the consumer migration mechanism. Stories are produced by a convergence cycle, so
  they now cite `ai-dlc-adversary-review`; a consumer that pinned the old bmad name in a
  pre-submission override breaks mid-sprint on its first story. **Nothing else can see it
  coming** — the reconcile finds the override's anchors unbroken, and a consumer check that
  asserts only "the `--require-skill` flag is present" is blind to *which* skill it names. So
  the failure itself carries the repair. `ai-dlc-update/SKILL.md` names the trap being avoided:
  *"a migration note in a CHANGELOG is how it never gets done."*

**V5 is the point of the fixture.** `validate-provenance-block.sh` says so in its own
header: *"a motivated forger can paste a well-formed block without invoking the
Skill."* V5 is that forger. It must PASS the lightweight pattern-match script and be
caught only by the heavyweight one, which resolves the cited SHA against git and
byte-compares the blob. That is the forgery floor.

## Run it

    ./run.sh                          # autodetects the validators
    ./run.sh --scripts ../../scripts  # or point at them

`seed.sh` writes the five variants and prints the directory. `run.sh` drives the real
validators against them and asserts the matrix above — standing up a throwaway git
repo with a real retro branch and a real committed transcript, so V5's SHA citation
has something to fail against.

Exit 0 means the floor holds. H2 item (2) re-drives this.

## Two bugs this fixture used to have, and why they mattered

**It wrote nothing.** `seed.sh` was two `echo` statements describing five variants
that were never created. H2 "re-drove" the fixture at every gate and adjudicated the
prose. A meta-check that reads a *description* of a test instead of running one
cannot fail — and it never did.

**V5 carried `mode: solo`.** That trips the Rule 20 solo assertion inside
`validate-provenance-block.sh`, which fires *before* the party-mode /
`transcript_path` branch is reached. So V5 failed the LIGHTWEIGHT script; the
byte-match assertion it exists to reach was never executed; the forgery floor went
untested — while this README asserted "V5 passes that script." It did not.

A fixture that short-circuits before the property it is testing is worse than no
fixture, because it reports PASS. `run.sh` therefore asserts that V5 passes the first
script *specifically so this cannot silently recur*: if V5 ever fails the lightweight
validator, run.sh fails loudly with `the forgery floor is UNTESTED` rather than
quietly counting it as one more correct rejection.
