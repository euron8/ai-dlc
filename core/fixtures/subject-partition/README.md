# subject-partition

Whether it ships is decided by the absence of a `.dist-only` marker
(`.claude/rules/fixture-ship-decl.md`). It ships: its subject, `partition-subject.sh`, is a core
script every consumer has at `scripts/ai-dlc/`. The fixture resolves it by walking up in either
layout.

- `run.sh` — arms S1–S8, X1–X9 and R. Every world is a mktemp git repository
  with trunk `main` and the sprint on a branch; the header states the discriminating inputs.
- `receipt.sh <tree>` — BL-458's receipt. It builds its own world, takes every program from
  `<tree>`, and exits 0 only when the subject is mapped (brief, SPEC, architecture-impact, ≥3 PRD
  parts including an edited earlier section), merged with `--subject`, and held by Check 24 arm
  K3. It exits 1 when a property is missing and 9 when it cannot measure.
