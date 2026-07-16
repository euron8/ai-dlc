# Fixture: relabel-theirs-collision

Adversarial self-test for `reconcile/relabel-extension-checks.sh`'s **theirs-awareness**.

## The bypass scenario

The tool defined "core" as the consumer's **installed** core. During a dry-run *before* apply,
that core does not yet carry the number the pull is about to add — so a **NEW-THIS-PULL
collision** (upstream adds `### 26.`; the consumer's extension already carries `### 26.`) reads as
"no collisions", while the reconcile report's needs-confirmation list — which compares against
theirs — correctly flags it. The operator sees a flagged collision with **no relabel option** at
the one moment they could decide it. Same class as the drift blind spot: a tool blind to what the
pull brings in.

The fix: pass `--dist <repo> --theirs <ref>` and the incoming core's numbers are **unioned** into
the collision set, so the dry-run previews exactly what apply will materialise. Backward
compatible — with neither flag, "core" is the installed core (correct at step 7, after the write).

## What it proves

- an unlabelled `### 26.` extension + installed core with no 26 + theirs core WITH 26 (a
  pull-created collision);
- **without** `--theirs` → "no collisions" (reproduces the blind spot);
- **with** `--theirs` (dry-run) → previews the `[ext:mydomain]` relabel, exit 1;
- `--apply` writes `### 26. [ext:mydomain] …` (integer unchanged) and a re-run is clean (idempotent).

## Run

    bash run.sh

Exit 0 = every assertion holds. Ships to consumers (it tests a shipped reconcile script); `run.sh`
resolves both the distribution and consumer layouts.
