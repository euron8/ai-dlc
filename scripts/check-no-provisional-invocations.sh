#!/usr/bin/env bash
# check-no-provisional-invocations.sh -- exit 0 iff no tracked core/fixtures/*/invocations.decl
# carries a `±` row. Receipt driver for BL-868. Exit 1: a `±` row remains. Exit 2: no
# invocations.decl is tracked at all (a glob matching nothing must not read as success).
set -u
d="$(cd "$(dirname "$0")/.." && pwd)" || exit 2
cd "$d" || exit 2
n="$(git ls-files -- 'core/fixtures/*/invocations.decl' | wc -l | tr -d ' ')" || exit 2
if [ "${n:-0}" -eq 0 ]; then
  echo "check-no-provisional-invocations: no tracked invocations.decl found" >&2
  exit 2
fi
if git grep -qF '±' -- 'core/fixtures/*/invocations.decl'; then
  exit 1
fi
exit 0
