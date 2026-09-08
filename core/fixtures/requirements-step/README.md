# Fixture: the `requirements` step replaces discovery + research-requirements

## What this guards

Release 3 (`0.531.0`) merges `discovery.md` and `research-requirements.md` into one
new step, `core/skills/ai-dlc/steps/requirements.md`, for the `carry-over` and
`feature` pipeline variants only. `greenfield`, `brownfield-a`, `brownfield-b` and
`brownfield-c` keep the old two-step sequence unchanged. That is a partition, not a
toggle: a fix that widens the merge to every variant, or a join that never moved for
`carry-over`/`feature`, both look like a clean tree to a check that reads only one
side.

Seven arms, each proven against a self-built `mktemp` offender and near-miss before
the corpus is ever read:

| Arm | Subject | Claim |
|---|---|---|
| (a) | `route.md` | `carry-over`/`feature` name `requirements` and not the old sequence; the other four variants still carry `discovery → research-requirements` |
| (b) | `requirements.md` | carries the loaded token, `nextStepFile: ./architecture.md`, and both `Adversarial review dispatch` / `Adversarial repair dispatch` substrings I11 needs |
| (c) | `carry-over-evaluation.md` | `nextStepFile: ./requirements.md` and its READ AND FOLLOW line names `requirements.md` |
| (d) | `gate-validation.md` | Check 24's "Those steps are:" list names `requirements`; Check 1c's body names the requirements gate and carries the skip-record regex |
| (e) | `requirements.md` | names `architecture-impact.md` and the token `architecture_impact:` |
| (f) | `SKILL.md` | Rule 8's `lightweight` row names `requirements` |
| (g) | `validate-draft-stamps.sh` | `DRAFTS=` contains `requirements-context` |

## Why the grammar is not a bare substring match

`requirements` is a substring of `research-requirements`, and "the requirements
gate" is a substring-adjacent phrase to "the research-requirements gate". A probe
built while writing this fixture caught both: the first draft's `route_row_names_requirements`
matched a row that still read `discovery → research-requirements` only, because the
row text literally contains `requirements`. The corpus arm was rewritten to strip
the compound token `research-requirements` before testing for the bare word, and
arm (d)'s Check 24 check anchors on the backtick-quoted token `` `requirements` ``
rather than a bare substring. Both directions of both probes are asserted, so a
regression back to either substring form fails the fixture's own self-probe (exit 2,
not a silent pass).

Check 24's "Those steps are:" list wraps across multiple lines in the real corpus —
`requirements` sits alone on its own line before a parenthetical about the
`lightweight` path. The line-joiner reads from the header through the terminating
sentence rather than the single line immediately after it, which a naive
`getline`-once reader would miss.

## Two layouts, one root

The steps directory resolves as `core/skills/ai-dlc/steps` here and
`.claude/skills/ai-dlc/steps` on an installed consumer. The project root is found by
walking up from this file for a `VERSION` marker, never by counting `..` hops — a
hop count answers differently from the repo root, a subdirectory, or a sandbox that
copied the fixture. If `requirements.md` is absent from the resolved steps
directory, the fixture prints `SKIP requirements-step: subject not installed` and
exits 0 — but only after every self-probe above has already run and proven it can
discriminate an offender from a near-miss, so a SKIP is never printed by a fixture
that could not have fired.

## Ships to consumers

No `.dist-only`. The subject — the installed step files under
`.claude/skills/ai-dlc/steps/` — is present on any consumer that has pulled release
3, which is exactly the population `fixture-ship-decl.md`'s criterion requires for a
shipping fixture.

## Removal condition

Retire this fixture if `requirements.md` is ever retired in favor of restoring the
two-step `discovery` / `research-requirements` sequence for `carry-over` and
`feature`, or if the merge is extended to every variant (at which point arm (a)'s
partition — the four variants that must still carry the old sequence — becomes
vacuous and needs rewriting, not deletion).
