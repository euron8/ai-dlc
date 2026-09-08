# Fixture: the architecture declared-no-impact fast-track

## What this guards

Release `0.532.0` widens the architecture step's Rule 5 fast-track so it can fire
at ANY `validation_intensity`, not only `lightweight`, when the Step 2 assessment
is NO CHANGES NEEDED and this sprint's
`_bmad-output/planning-artifacts/s<N>/architecture-impact.md` (written by
`requirements.md` §4) declares no architectural impact on every line. The
predicate that decides "no impact" is a single fenced `awk` line in
`architecture.md` §4, marked by `<!-- FAST_TRACK_PREDICATE -->`, and
`gate-validation.md` Check 20 must run that same predicate — not restate it —
against the same file, and record the same gate-log token when it fires.

Five arms, each proven against a self-built `mktemp` offender and near-miss
before the corpus is ever read:

| Arm | Subject | Claim |
|---|---|---|
| (a) | `architecture.md` §4 intensity bullet | names `architecture-impact.md` and the literal `architecture_impact: none`, and does not read as the old lightweight-only form |
| (b) | the `FAST_TRACK_PREDICATE` awk line | is extracted from `architecture.md` and EXECUTED (never paraphrased) against an eight-row seed table covering the case the plan names by name (`none-for-now`), capitalization, trailing whitespace, other text, an empty file, a file with no matching line, and a missing file |
| (c) | `gate-validation.md` Check 20 body | names `architecture-impact.md`, the token `fast_track: architecture-impact-none`, and `architecture.md` |
| (d) | `requirements.md` §4 | still writes what the predicate reads: names `architecture-impact.md` and carries the literal `architecture_impact: none` |
| (e) | the `fast_track:` token | is byte-identical between `architecture.md` and `gate-validation.md` Check 20 |

## Why arm (b) extracts and runs the predicate rather than reading it

A check that reads the predicate's text and reasons about it in prose can drift
from what the predicate actually does. Arm (b) locates the marker comment, takes
the line two lines below it (marker, fence, predicate), asserts that extraction
returned a non-empty line naming `architecture_impact`, then runs that exact
line — `f="$seed" bash -c "$P"` — against seeds in a `mktemp` directory and reads
the real exit code. This is what stops the arm from becoming a paraphrase of the
predicate that would go stale the moment the awk changed underneath it.

That extraction-and-execution arm still needs its own probe: a check that merely
runs the shipped predicate correctly could also pass if the predicate were subtly
wrong, because there is nothing yet proving the SEED TABLE can tell a wrong
predicate from a right one. The fixture runs a deliberately loose stand-in
(`grep -q 'architecture_impact: none' "$f"`) through the same table and asserts
it WRONGLY passes the `none-for-now` seed — the case the plan calls out by name,
where a substring match would accept `architecture_impact: none-for-now` as
`none`. Only after that loose predicate is shown to fail is the real predicate
trusted to have been meaningfully tested by the table.

## Why arm (c) does not use a getline-once reader

Check 20's body spans many lines between its `### 20.` header and the next
`### 21.` header, and the tokens this arm needs can sit anywhere in that range —
`requirements-step`'s README records the same trap for its own Check 24 arm. The
section-range grammar here (`awk` with a `grab` flag that starts at `### 20.` and
stops at the next `### `) is proven with a probe file that places its token on
the last line before the `### 21.` boundary, so a reader that only inspects the
first line or two after the header cannot pass it by accident.

## Two layouts, one root

The steps directory resolves as `core/skills/ai-dlc/steps` here and
`.claude/skills/ai-dlc/steps` on an installed consumer. **The project root is
three `..` hops up from this file, never a `VERSION`-marker walk** (I106): this
fixture ships, and an installed consumer has no `VERSION` file at its root (its
stamp is `.claude/.ai-dlc-version`), so a walk-up for one would resolve to
nothing there and the fixture would exit 2 on every consumer push. If
`architecture.md` is absent from the resolved steps directory, the fixture
prints `SKIP architecture-fast-track: subject not installed` and exits 0 — but
only after every self-probe above has already run and proven it can
discriminate an offender from a near-miss, so a SKIP is never printed by a
fixture that could not have fired.

## Ships to consumers

No `.dist-only`. The subject — the installed step files under
`.claude/skills/ai-dlc/steps/` — is present on any consumer that has pulled
release `0.532.0`, which is exactly the population `fixture-ship-decl.md`'s
criterion requires for a shipping fixture.

## Removal condition

Retire this fixture if the declared-no-impact fast-track is ever removed from
`architecture.md` §4, or if `gate-validation.md` Check 20 stops naming the
predicate file and instead reads gate-log claims unconditionally (at which
point arm (c)'s claim that the check RUNS the predicate rather than trusting the
log becomes moot and needs rewriting, not deletion).
