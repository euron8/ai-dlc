---
paths:
  - "core/fixtures/**"
---

<!-- no-stub: by operator ruling there is no CLAUDE.md pointer, because the
     compaction-durable channel is at its byte ceiling and a pointer would spend it.
     The carrier of the "One run per distinct state" section is the push failure:
     the invocation budget's J3 remedy text names that section by its title, so
     the rule reaches whoever the budget refuses. -->

# Building good arms

No fixture carries a mutation battery; `scripts/validate-fixture-hygiene.sh` arm H12 fails the push on one. That an
arm can fail is proved once, by hand, at authoring (`CLAUDE.md`, "Build process", builder step 4).

- Make every arm **PRESENCE-shaped**: it requires a specific row or message to APPEAR, so a subject that emits nothing
  fails it by construction. A control asserting rc=0-and-no-findings passes against a subject replaced by `exit 0`;
  give every control a positive conjunct that a baseline row is THERE.
- Assert a **positive outcome**, not the absence of the old failure message. A regression that WIDENS a guard to match
  everything often produces the same output as the original. Make the guard match NOTHING.
- **A DENY arm alone cannot tell a correctly-keyed guard from one that denies unconditionally.** Every denied cell
  needs its ALLOW twin in the SAME run, one property apart.
- **An ABSENCE-shaped arm passes against a subject that emits nothing.** Ask of every new arm whether it would pass
  against `exit 0`; if yes, reshape it to require a row.
- **Two guards that COVER each other read exactly like two guards that do not work.** Give every guard a subject the
  OTHER guards cannot see; ask of each new guard which existing one would still cover its subject.
- **Keep the fixture's author different from the arm's.** An arm and a fixture written by the same hand encode one
  understanding twice.
- **Never seed from what the reader accepts.** Seed from what the real producer emits.
- **A near-miss must carry every property a feared regression would KEY on.** Read which property of the offender the
  near-miss lacks, and seed a second near-miss that has it.
- **A fixture whose tree cannot EXPRESS the defect proves nothing.** Check the seed reaches the branch under test,
  exercise a layout-conditional resolver against every root shape it claims to handle, and give the unit a positive
  control so a harness that died reports as broken rather than as clean.
- **When a guard flips no verdict, arm it on COST**, on the first observable that guard actually gates. An arm that
  survives deleting its own subject is watching the wrong thing.
- **A PRESENCE-shaped arm catches quoting bugs an absence-shaped one hides.** Backticks inside a double-quoted
  assertion string run as a command.
- **Killing a backgrounded subject means reaping its TREE**, by its recorded process group, never one level of
  `pkill -P`.
- **Hardening worlds DISPLACE the motivating world; keep it as its own case, asserted as a number.** Every count a
  message prints is hardcodable until a world exists where it differs.
- **`exit` inside `$( )` ends the subshell, not the fixture.** Check the captured value at the call site. A seed
  defines the WHOLE consumer state, removing what it does not write.
- **A fixture with more than one world records each world's refs IN the world.** Write `.B`/`.T` beside the world
  and have every helper read those.
- **Print the path the fixture RESOLVES.** A fixture that names candidates in both install layouts takes the first that
  exists (`core/git-hooks/pre-push` before `.githooks/pre-push`).
- **A seeded SET with one member cannot tell "scanned the set" from "scanned its first member".** Seed the
  discriminating member NOT first, and seed an epoch row that is not the subject.
- **A fact about what the corpus contains TODAY is not a fact about what the mechanism must HANDLE.** Synthesise a
  world the corpus lacks when it is REACHABLE under the mechanism's own contract; a world the subject refuses is the
  contract, not a gap.
- **Shared logic is a reason to go read the other side's seeds, never a reason to skip them.**
- **Ask what a wrong output makes someone DO, not what it makes the program say.**

## One run per distinct state

A fixture pays for each run of its subject, so the number of runs is part of its design. These clauses bind every
fixture.

1. **One subject run per distinct state.** Assertions about one state read one run's output; they do not each re-run
   the subject.
2. Retired: no fixture carries a mutation battery.
3. **No control is re-run per variant.** Run the control once and compare each variant against its output.
4. **Build each world once and copy it.** A world constructed per assertion is a world built many times.
5. **Use the subject's cheap mode.** Where none exists for a one-piece question, add a seam that calls the SAME
   function the subject calls, never a copy of it.
6. **One end-to-end run per distinct outcome proves the wiring.** The remaining cells exercise the function directly.
7. **A fixture never SKIPs with exit 0 on a condition true in normal use**, such as a linked-worktree `.git` or a
   missing declared tool. The skip reads as a pass. Exit 2 with FIXTURE BROKEN instead.

Clauses 1 and 3 through 6 have one mechanism, the invocation budget (`scripts/validate-fixture-invocations.sh`, run
inside `core/scripts/hermetic-run.sh`): it refuses the regrowth of a fixture's start count. Clause 7 is held by
`scripts/validate-fixture-hygiene.sh` arms H1, H2 and H3.
