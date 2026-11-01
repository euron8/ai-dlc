#!/usr/bin/env bash
# check-no-provisional-invocations.sh -- exit 0 iff no tracked core/fixtures/*/invocations.decl
# carries a `±` row. Receipt driver for BL-868. Exit 1: a `±` row remains. Exit 9: could not
# measure -- the root did not resolve, `git ls-files` failed, or no invocations.decl is tracked at
# all (a glob matching nothing must not read as success). 9 is the receipt convention's could-not-
# measure code, which validate-backlog-receipts.sh's R7 refuses, so a missing subject is never read
# as a live defect (1) or a fix (0).
set -uo pipefail
d="$(cd "$(dirname "$0")/.." && pwd)" || exit 9
cd "$d" || exit 9
n="$(git ls-files -- 'core/fixtures/*/invocations.decl' | wc -l | tr -d ' ')" || exit 9
if [ "${n:-0}" -eq 0 ]; then
  echo "check-no-provisional-invocations: no tracked invocations.decl found" >&2
  exit 9
fi
if git grep -qF '±' -- 'core/fixtures/*/invocations.decl'; then
  exit 1
fi
exit 0
