# Check 17 (Skill-Invocation Provenance) Bypass Fixture

Five variants of a forged or broken `SKILL_INVOCATION_PROVENANCE v1` block.

| Variant | File | Defect | `validate-provenance-block.sh` | `validate-retro-evidence.sh` |
|---|---|---|---|---|
| V1 | `sprint-901.md` | no provenance block at all | FAIL | — |
| V2 | `sprint-902.md` | `tool_use_id` stripped | FAIL | — |
| V3 | `sprint-903.md` | `skill:` names an unknown skill | FAIL | — |
| V4 | `sprint-904.md` | `transcript_path` missing `@<sha>` | FAIL | — |
| V5 | `sprint-905.md` | well-formed block, **fabricated SHA** | **PASS** | **FAIL** |

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
