#!/usr/bin/env bash
# Seed the check-1c-bypass fixture
# Creates a branch with a misleading commit subject that naive greps would match
set -euo pipefail
echo "Fixture: check-1c-bypass"
echo "Creates a commit with embedded 'research' in non-research context"
echo "PRD has no R-marker lines"
echo "Check 1c anchored regex should FAIL on this scenario"
