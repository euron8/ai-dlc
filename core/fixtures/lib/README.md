# `core/fixtures/lib/` — the shared fixture preamble

Not a fixture. This directory holds `preamble.sh`, the seam every fixture `run.sh`
that builds a scratch repository sources before its first git call.

**No `run.sh`, deliberately.** There is no condition here to drive. The file is a
sourced fragment whose entire body is one `unset`, and its behaviour is observable
only inside a fixture that sources it — so a driver here would either re-test the
`unset` builtin or duplicate the arms that already live in
`core/fixtures/fixture-git-env-seam/run.sh`. What binds this directory is
`scripts/validate-fixture-git-env.sh`, which fails the push when the seam is
absent, when it does not actually unset `GIT_DIR`, or when a fixture in the derived
population does not source it.

**Why the seam exists.** Git exports `GIT_DIR` absolute to any hook run from a
linked worktree. A fixture invoked directly — `bash core/fixtures/X/run.sh`, the
invocation `CLAUDE.md` prescribes for debugging one — inherits it, and `git init`
under an inherited `GIT_DIR` silently succeeds *without creating a repository*.
Every later git call in that fixture then lands on the caller's repository.
Measured across eight fixtures, fresh victim per trial, against an unarmed control
that left all eight intact: 8 of 8 wiped a 757-entry index, 6 of them at exit 0
with zero FAILs reported.

The two pre-push hooks scrub before dispatching the pool, so the suite was never
exposed. A direct invocation passes through no seam at all, which is what this
directory is.

**It ships.** A consumer's `tests/fixtures/lib/preamble.sh` is sourced by the
consumer's own copies of these fixtures, resolved relative to the sourcing file, so
the path holds in both layouts. It carries no `.dist-only` marker for that reason.
