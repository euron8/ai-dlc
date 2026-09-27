# Fixture: emit-report-refusal

Self-test for the refusal half of `reconcile/emit-report.sh`. When a sample or detector did not
run, the reconcile report must say so with a column-0 `DETECTOR-REFUSED` line. It must never show
`none`, because the operator reads `none` as a clean finding.

## What it proves

- Each detector site that renders a detector's rows refuses rather than rendering `none` when
  that detector exits non-zero, and relabel's exit 1 still renders as a finding.
- The orientation block reads every status. A failed `diff` refuses only the file it failed on.
  A failed or non-numeric sample refuses only its side. A failed `ls-tree` or `git show` refuses,
  and a path truly absent upstream still renders `THEIRS absent`.
- `--verify` of a resolved-blocker report whose fresh render refuses reads `UNDECIDED`, never
  `BLOCKERS-RESOLVED`.
- The orientation diff survives a forced interleaving that makes a process-substitution operand
  fail every time.
- The `reconcile-emit-report` fixture's R6 guard retries a world approved or scored under a
  transient refusal. It keeps the seed's own legitimate refusal and a stubbed sibling's
  intended one.

Every arm has a mutant of the shipped source, built in a copy of the whole `reconcile/`
directory, and each mutant must fail exactly its own arms.

## Run

    bash run.sh

This unit runs the sibling `reconcile-emit-report/seed.sh`, so both directories must be present.
Exit 0 means every assertion holds. The fixture ships to consumers.
