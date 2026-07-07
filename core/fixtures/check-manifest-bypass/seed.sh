#!/usr/bin/env bash
# Seed the check-manifest-bypass fixture
# Simulates a gate that declares `implementation` but loads only the
# planning slice, omitting implementation-required checks. H1's
# manifest-completeness pass MUST FAIL this scenario.
set -euo pipefail
echo "Fixture: check-manifest-bypass"
echo "Declared gate type: implementation"
echo "Loaded slice: universal core + planning row (1c, 17, 20)"
echo "Omitted implementation-required checks: 5, 6, 8, 9, 10, 11, 11a, 19, 22"
echo "Present CHECK_LOADED anchors (planning slice):"
echo "  1 2 3 4 7 12 13 14 15 16 H1 H2 failure 1c 17 20"
echo "Missing required anchors for declared type implementation:"
echo "  5 6 8 9 10 11 11a 19 22"
echo "Expected: H1 manifest-completeness FAILS, naming >=1 missing anchor (e.g. CHECK_LOADED: 6)"
