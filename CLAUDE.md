# Authoring rules — ai-dlc itself

Scope: work in THIS repo (`core/`, `scripts/`, `core/fixtures/`).

Everything under `templates/` is the consumer distribution's output, not this
repo's rulebook. `install.sh` copies `coding-conventions.md.template` to the
consumer's `docs/coding-conventions.md` and `CLAUDE.md.template` to the
consumer's `CLAUDE.md`. **That last one shares this file's basename and is a
different file** — do not put ai-dlc-authoring rules in the template, do not
treat the template as binding here, and check which of the two you have open
before editing.

## A zero is not a finding

Any command whose answer is an ABSENCE carries a control, in the same invocation,
that must come back non-zero. Report both. Without one you have established that
your search ran, not that the thing is missing.

Measured false-zero sources, each of which has shipped a wrong conclusion here:

- **Unbraced `$ref:path` in zsh.** `:c` and `:t` are history modifiers and
  silently eat the next character — `"$r:core/..."` becomes `f70512eore/...` and
  git reports the path absent. Always `"${r}:core/..."`.
- **Case-sensitive grep against a differently-cased token** — a lowercase `v8`
  against an uppercase `V8` banner.
- **A per-file grep against a glob-declared list.** `core-manifest.md` declares
  `steps/*.md`; grepping it for one step file's name returns 0 for every step
  file and proves nothing.
- **An empty or `.` pathspec.** `:(exclude)` with no value excludes the whole
  tree, and `git grep` then exits **1, not 128** — indistinguishable from a real
  absence.

## A check that cannot fire reads exactly like one that passed

Before shipping a check, prove it can fail. This is the repo's recurring defect;
roughly a dozen files state it locally, in the header of whichever guard learned
it. Those statements stay where they are — each explains its own guard. This is
the general form.

## Mutants

- Build the mutant as a **copy**, never an in-place edit, and guard with `cmp -s`
  so a `sed` that matched nothing cannot pass as a mutation.
- **Revert every layer of a layered fix.** A partial revert produces a mutant
  that proves the layer you left in place, and it comes out green.
- Add an **unmutated control** from the same directory whenever the harness
  itself could be what fails — a lone script copy that dies sourcing `lib.sh`
  emits nothing, and "no output" otherwise scores as a kill.
- Assert a **positive outcome**, not the absence of the old failure message.
- A mutant must fail **only** its own assertion. Two failures mean the
  assertions are entangled and one of them is vacuous.

## Two layouts

`install.sh` splits what shares a parent here: `core/scripts/<x>` →
`scripts/ai-dlc/<x>`, `core/schemas/` → `.claude/schemas/`. Never locate one core
file by walking up from another — invariant **I33** fails the build on it. Any
change touching path resolution is verified on a tree built by running
`scripts/install.sh` into an empty directory, not only in `core/`.

## Prohibitions need mechanisms

A rule with no enforcer is a suggestion, and the prohibitions being violated are
exactly the ones with nothing behind them. Prefer deriving both sides of a join
over hand-listing either; when two files must agree, bind them — the numbered
invariants in `scripts/validate-enforcement-map.sh` are the pattern, and its
final `OK:` line enumerates the ones currently live.

## Before adding a check, measure its false-positive set

Ship it only if you have run it and the set is empty or enumerated. An unmeasured
lint is one the operator turns off, which is worse than none.

## Releases

Commit subject, `VERSION`, and the `CHANGELOG` heading are **one claim**, joined
at pre-push. Squash-merge only single-version branches: a squash of several takes
the first version in the subject and breaks the triple.
