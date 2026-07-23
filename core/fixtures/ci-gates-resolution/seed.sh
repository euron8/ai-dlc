#!/usr/bin/env bash
# Seed the ci-gates-resolution fixture. There are no static seed files: run.sh builds
# its own throwaway trees under mktemp per assertion, because the subject is which
# enforcement surface / alias table the validator is pointed at, and each assertion needs
# a different one. This script exists so the fixture has the seed.sh the packaging
# contract expects; the real setup is in run.sh.
set -euo pipefail
echo "Fixture: ci-gates-resolution (validate-ci-gates.sh enforcement matching)"
echo "No static files — run.sh builds temp trees and drives the validator through"
echo "AI_DLC_PROJECT_ROOT / AI_DLC_RETRO_DIR / AI_DLC_CI_SURFACE / AI_DLC_CI_ALIAS_TABLE."
