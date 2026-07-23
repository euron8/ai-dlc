#!/usr/bin/env bash
# Seed the shadowed-local-validators fixture. No static seed files: run.sh builds its own
# throwaway consumer tree under mktemp (ledger + local forks + core validators) because the
# subject is which combination of ledger-state and on-disk forks the signal fires on, and
# each assertion needs a different one. This script exists so the fixture has the seed.sh
# the packaging contract expects; the real setup is in run.sh.
set -euo pipefail
echo "Fixture: shadowed-local-validators (warn-shadowed-local-validators.sh retirement signal)"
echo "No static files — run.sh builds a temp consumer tree and drives the script through"
echo "--root / --ledger / --local-dir / --core-dir."
